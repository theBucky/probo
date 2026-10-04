import Foundation
import IOKit.pwr_mgt
import os

// Holds a prevent-idle-sleep assertion for its lifetime; display sleep, lid close, and manual sleep still fire.
final class IdleSleepAssertion {
  private static let logger = Logger(subsystem: "com.probo.app", category: "Power")

  private let assertionID: IOPMAssertionID

  init?() {
    var assertionID: IOPMAssertionID = 0
    let result = IOPMAssertionCreateWithDescription(
      kIOPMAssertPreventUserIdleSystemSleep as CFString,
      "Probo" as CFString,
      "Prevent automatic sleep while Probo is enabled." as CFString,
      "Probo is keeping your Mac awake." as CFString,
      Bundle.main.bundlePath as CFString,
      0,
      nil,
      &assertionID
    )
    guard result == kIOReturnSuccess else {
      Self.logger.error("failed to create idle sleep assertion: \(result, privacy: .public)")
      return nil
    }
    self.assertionID = assertionID
  }

  deinit {
    let result = IOPMAssertionRelease(assertionID)
    if result != kIOReturnSuccess {
      Self.logger.error(
        "failed to release idle sleep assertion \(self.assertionID, privacy: .public): \(result, privacy: .public)"
      )
    }
  }
}
