@preconcurrency import ApplicationServices

enum LookUpGesture {
  private static let buttonNumber: Int64 = 3
  private static let keyCode = KeyboardKeyCode.d
  private static let flags: CGEventFlags = [.maskCommand, .maskControl]

  static func consume(type: CGEventType, event: CGEvent) -> Bool {
    guard event.getIntegerValueField(.mouseEventButtonNumber) == buttonNumber else {
      return false
    }
    if type == .otherMouseDown {
      post()
    }
    return true
  }

  private static func post() {
    guard
      let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
      let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else { return }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cgSessionEventTap)
    up.post(tap: .cgSessionEventTap)
  }
}
