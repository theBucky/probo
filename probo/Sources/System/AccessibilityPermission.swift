@preconcurrency import ApplicationServices
import Foundation

enum AccessibilityPermission {
  static let trustChangedNotification = Notification.Name("com.apple.accessibility.api")

  static func isTrusted(prompt: Bool) -> Bool {
    guard prompt else { return AXIsProcessTrusted() }
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
  }
}
