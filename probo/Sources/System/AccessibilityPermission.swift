@preconcurrency import ApplicationServices

enum AccessibilityPermission {
  static func isTrusted(prompt: Bool) -> Bool {
    guard prompt else { return AXIsProcessTrusted() }
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
  }
}
