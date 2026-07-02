import Foundation
import IOKit.pwr_mgt
import os

final class IdleSleepAssertion {
  private static let logger = Logger(subsystem: "com.probo.app", category: "Power")
  private var assertionID: IOPMAssertionID?

  deinit {
    if let assertionID {
      releaseSystemAssertion(assertionID)
    }
  }

  @MainActor
  func setEnabled(_ enabled: Bool) {
    if enabled {
      guard assertionID == nil else { return }
      guard let createdAssertionID = createSystemAssertion() else {
        Self.logger.error("failed to create idle sleep assertion")
        return
      }
      assertionID = createdAssertionID
      return
    }

    guard let activeAssertionID = assertionID else { return }
    releaseSystemAssertion(activeAssertionID)
    assertionID = nil
  }

  private func createSystemAssertion() -> IOPMAssertionID? {
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

    guard result == kIOReturnSuccess else { return nil }
    return assertionID
  }

  private func releaseSystemAssertion(_ assertionID: IOPMAssertionID) {
    let result = IOPMAssertionRelease(assertionID)
    if result != kIOReturnSuccess {
      Self.logger.error(
        "failed to release idle sleep assertion \(assertionID, privacy: .public): \(result, privacy: .public)"
      )
    }
  }
}
