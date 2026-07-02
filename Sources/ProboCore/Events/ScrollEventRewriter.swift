@preconcurrency import ApplicationServices

package struct ScrollEventRewriter {
  private let synth = ScrollEventSynthesizer()
  private let isTerminalFrontmost: @Sendable () -> Bool
  private static let leftOptionFlag = CGEventFlags(rawValue: 0x20)
  private static let rightOptionFlag = CGEventFlags(rawValue: 0x40)
  private static let allOptionFlags: CGEventFlags = [
    .maskAlternate, leftOptionFlag, rightOptionFlag,
  ]
  private static let leftOptionKey = CGKeyCode(0x3A)
  private static let rightOptionKey = CGKeyCode(0x3D)

  package init(isTerminalFrontmost: @escaping @Sendable () -> Bool) {
    self.isTerminalFrontmost = isTerminalFrontmost
  }

  // EventTapController filters self-synth re-entry; the core owns the drop decision.
  package func rewrite(event: CGEvent, options: EventTapOptions) -> CGEvent? {
    guard Self.isDiscreteWheelEvent(event) else { return event }

    let verticalDelta = Int32(
      truncatingIfNeeded: event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    let horizontalDelta = Int32(
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
        verticalDelta: verticalDelta,
        horizontalDelta: horizontalDelta,
        intensity: options.intensity,
        isPrecision: decision.isPrecision,
        isTrackpadStyleScrollingEnabled: options.isTrackpadStyleScrollingEnabled
      )
    else { return nil }

    if !decision.stripOption {
      synth.applyReplacement(to: event, linesX: linesX, linesY: linesY)
      return event
    }

    // stripOption implies option was held; sandwich the stripped replacement with flagsChanged
    // so the target app sees option release before our event and restore after. The replacement
    // is required: skipping the sandwich on flagsChanged synthesis failure still beats passing
    // the original Option-bearing event through, which terminals would read as alt-scroll.
    let flags = originalFlags.subtracting(Self.allOptionFlags)
    let optionKey: CGKeyCode =
      originalFlags.contains(Self.rightOptionFlag)
      ? Self.rightOptionKey : Self.leftOptionKey
    guard
      let replacement = synth.makeReplacement(
        location: event.location, flags: flags, linesX: linesX, linesY: linesY
      )
    else { return event }

    let releaseOption = synth.makeFlagsChanged(flags: flags, keyCode: optionKey)
    let restoreOption = synth.makeFlagsChanged(flags: originalFlags, keyCode: optionKey)

    releaseOption?.post(tap: .cgSessionEventTap)
    replacement.post(tap: .cgSessionEventTap)
    restoreOption?.post(tap: .cgSessionEventTap)
    return nil
  }

  // Trackpad and Magic Mouse scrolling is continuous or phased; wheel notches are neither.
  private static func isDiscreteWheelEvent(_ event: CGEvent) -> Bool {
    if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventScrollPhase) != 0 { return false }
    if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 { return false }
    let subtype = CGEventMouseSubtype(
      rawValue: UInt32(event.getIntegerValueField(.mouseEventSubtype)))
    if subtype != .defaultType { return false }
    return event.getIntegerValueField(.tabletEventDeviceID) == 0
  }
}
