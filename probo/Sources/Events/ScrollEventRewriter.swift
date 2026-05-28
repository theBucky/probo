@preconcurrency import ApplicationServices

struct ScrollEventRewriter {
  private let synth = ScrollEventSynthesizer()
  private let isTerminalFrontmost: @Sendable () -> Bool

  init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    self.isTerminalFrontmost = isTerminalFrontmost
  }

  // EventTapController filters self-synth re-entry; the core owns the drop decision.
  func rewrite(event: CGEvent, options: EventTapOptions) -> Bool {
    guard isMouseWheelEvent(event) else { return false }

    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    let hasPhase =
      event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
      || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    let deltaAxis1 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let deltaAxis2 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))

    let originalFlags = event.flags
    let decision = ScrollRewriteCore.decidePrecision(
      isOptionHeld: originalFlags.contains(.maskAlternate),
      isOptionPrecisionEnabled: options.isOptionPrecisionEnabled,
      isTerminalOptimizationActive:
        options.isTerminalOptimizationEnabled && isTerminalFrontmost(),
    )
    guard
      let (linesX, linesY) = ScrollRewriteCore.rewrite(
        deltaAxis1: deltaAxis1,
        deltaAxis2: deltaAxis2,
        intensity: options.intensity,
        isContinuous: isContinuous,
        hasPhase: hasPhase,
        isPrecision: decision.isPrecision,
        isTrackpadStyleScrollingEnabled: options.isTrackpadStyleScrollingEnabled
      )
    else { return false }

    return post(
      location: event.location,
      originalFlags: originalFlags,
      linesX: linesX,
      linesY: linesY,
      stripOption: decision.stripOption
    )
  }

  private func isMouseWheelEvent(_ event: CGEvent) -> Bool {
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType { return false }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }

  private func post(
    location: CGPoint,
    originalFlags: CGEventFlags,
    linesX: Int32,
    linesY: Int32,
    stripOption: Bool
  ) -> Bool {
    if !stripOption {
      guard
        let replacement = synth.makeReplacement(
          location: location, flags: originalFlags, linesX: linesX, linesY: linesY
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
        location: location, flags: flags, linesX: linesX, linesY: linesY
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
