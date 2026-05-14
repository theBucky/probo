@preconcurrency import ApplicationServices

struct ScrollEventRewriter {
  private let synth: ScrollEventSynthesizer
  private let isTerminalFrontmost: @Sendable () -> Bool

  init(marker: Int64, isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    self.isTerminalFrontmost = isTerminalFrontmost
    synth = ScrollEventSynthesizer(marker: marker)
  }

  // EventTapController filters self-synth re-entry before calling here.
  func rewrite(event: CGEvent, configuration: AppConfiguration) -> Bool {
    guard isMouseWheelEvent(event) else {
      return false
    }

    let originalFlags = event.flags
    let decision = ScrollRewriteCore.decidePrecision(
      isOptionHeld: originalFlags.contains(.maskAlternate),
      isOptionPrecisionEnabled: configuration.isOptionPrecisionEnabled,
      isTerminalOptimizationActive:
        configuration.isTerminalOptimizationEnabled && isTerminalFrontmost(),
    )
    let input = ScrollRewriteInput(
      deltaAxis1: Int32(
        truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1)),
      deltaAxis2: Int32(
        truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
      intensity: configuration.intensity,
      isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
      hasPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
        || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0,
      isPrecision: decision.isPrecision,
      isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled
    )

    guard let output = ScrollRewriteCore.rewrite(input) else {
      return false
    }

    return post(
      location: event.location,
      originalFlags: originalFlags,
      output: output,
      stripOption: decision.stripOption
    )
  }

  private func isMouseWheelEvent(_ event: CGEvent) -> Bool {
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType {
      return false
    }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }

  private func post(
    location: CGPoint,
    originalFlags: CGEventFlags,
    output: ScrollRewriteOutput,
    stripOption: Bool
  ) -> Bool {
    if !stripOption {
      guard
        let replacement = synth.makeReplacement(
          location: location, flags: originalFlags, linesX: output.linesX, linesY: output.linesY
        )
      else { return false }
      replacement.post(tap: .cgSessionEventTap)
      return true
    }

    // stripOption implies option was held; sandwich the stripped replacement with flagsChanged
    // so the target app sees option release before our event and restore after. The replacement
    // is required: skipping the sandwich on flagsChanged synthesis failure still beats passing
    // the original Option-bearing event through, which terminals would read as alt-scroll.
    let flags = originalFlags.subtracting(.proboAllOption)
    let optionKey: CGKeyCode =
      originalFlags.contains(.proboRightOption)
      ? KeyboardKeyCode.rightOption : KeyboardKeyCode.option
    guard
      let replacement = synth.makeReplacement(
        location: location, flags: flags, linesX: output.linesX, linesY: output.linesY
      )
    else { return false }

    let releaseOption = synth.makeFlagsChanged(flags: flags, keyCode: optionKey)
    let restoreOption = synth.makeFlagsChanged(flags: originalFlags, keyCode: optionKey)

    releaseOption?.post(tap: .cgSessionEventTap)
    replacement.post(tap: .cgSessionEventTap)
    restoreOption?.post(tap: .cgSessionEventTap)
    return true
  }
}
