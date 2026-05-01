@preconcurrency import ApplicationServices

struct ScrollEventRewriter {
  private let marker: Int64
  private let synth: ScrollEventSynthesizer

  init(marker: Int64) {
    self.marker = marker
    synth = ScrollEventSynthesizer(marker: marker)
  }

  func rewrite(event: CGEvent, configuration: AppConfiguration) -> Bool {
    // self-synthesized events re-enter the session tap; bail before any other field reads.
    if event.getIntegerValueField(.eventSourceUserData) == marker {
      return false
    }
    guard isMouseWheelEvent(event) else {
      return false
    }

    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    let hasPhase =
      event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0
      || event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
    let deltaAxis1 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let deltaAxis2 = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
    let originalFlags = event.flags
    let isPrecision =
      configuration.isPrecisionScrollEnabled && originalFlags.contains(.maskAlternate)

    guard
      let output = ScrollRewriteCore.rewrite(
        ScrollRewriteInput(
          deltaAxis1: deltaAxis1,
          deltaAxis2: deltaAxis2,
          intensity: configuration.intensity,
          isContinuous: isContinuous,
          hasPhase: hasPhase,
          isPrecision: isPrecision,
          isTrackpadStyleScrollingEnabled: configuration.isTrackpadStyleScrollingEnabled
        ))
    else {
      return false
    }

    if isPrecision {
      return postPrecision(location: event.location, originalFlags: originalFlags, output: output)
    }
    return postSteps(location: event.location, flags: originalFlags, output: output)
  }

  private func isMouseWheelEvent(_ event: CGEvent) -> Bool {
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType {
      return false
    }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }

  private func postPrecision(
    location: CGPoint, originalFlags: CGEventFlags, output: ScrollRewriteOutput
  ) -> Bool {
    let flags = originalFlags.subtracting(.proboAllOption)
    let optionKey: CGKeyCode =
      originalFlags.contains(.proboRightOption)
      ? KeyboardKeyCode.rightOption : KeyboardKeyCode.option
    guard
      let replacement = synth.makeReplacement(
        location: location, flags: flags, linesX: output.linesX, linesY: output.linesY
      ),
      let releaseOption = synth.makeFlagsChanged(flags: flags, keyCode: optionKey),
      let restoreOption = synth.makeFlagsChanged(flags: originalFlags, keyCode: optionKey)
    else {
      return false
    }

    releaseOption.post(tap: .cgSessionEventTap)
    replacement.post(tap: .cgSessionEventTap)
    restoreOption.post(tap: .cgSessionEventTap)
    return true
  }

  private func postSteps(
    location: CGPoint, flags: CGEventFlags, output: ScrollRewriteOutput
  ) -> Bool {
    guard
      let replacement = synth.makeReplacement(
        location: location, flags: flags, linesX: output.linesX, linesY: output.linesY
      )
    else { return false }
    replacement.post(tap: .cgSessionEventTap)
    return true
  }
}
