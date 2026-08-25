@preconcurrency import ApplicationServices
import Foundation

enum AccessibilityPermission {
  private static let trustChangedNotification = Notification.Name("com.apple.accessibility.api")

  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  static func request() -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
  }

  @MainActor
  static func observeTrustChanges(onChange: @escaping @MainActor () -> Void) -> Task<Void, Never> {
    Task { @MainActor in
      let stream = DistributedNotificationCenter.default()
        .notifications(named: trustChangedNotification)
      for await _ in stream {
        onChange()
      }
    }
  }
}
