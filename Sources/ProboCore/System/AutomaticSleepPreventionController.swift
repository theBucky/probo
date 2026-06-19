import Foundation
import IOKit.pwr_mgt
import os

final class AutomaticSleepPreventionController {
  private static let logger = Logger(subsystem: "com.probo.app", category: "Power")

  private let createAssertion: () -> IOPMAssertionID?
  private let releaseAssertion: (IOPMAssertionID) -> Void
  private var assertionID: IOPMAssertionID?

  init(
    createAssertion: @escaping () -> IOPMAssertionID? =
      AutomaticSleepPreventionController.createSystemAssertion,
    releaseAssertion: @escaping (IOPMAssertionID) -> Void =
      AutomaticSleepPreventionController.releaseSystemAssertion
  ) {
    self.createAssertion = createAssertion
    self.releaseAssertion = releaseAssertion
  }

  deinit {
    if let assertionID {
      releaseAssertion(assertionID)
    }
  }

  @MainActor
  func setEnabled(_ enabled: Bool) {
    if enabled {
      guard assertionID == nil else { return }
      guard let createdAssertionID = createAssertion() else {
        Self.logger.error("failed to prevent automatic sleep")
        return
      }
      assertionID = createdAssertionID
      return
    }

    guard let activeAssertionID = assertionID else { return }
    releaseAssertion(activeAssertionID)
    assertionID = nil
  }

  private static func createSystemAssertion() -> IOPMAssertionID? {
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

  private static func releaseSystemAssertion(_ assertionID: IOPMAssertionID) {
    let result = IOPMAssertionRelease(assertionID)
    if result != kIOReturnSuccess {
      logger.error(
        "failed to release automatic sleep assertion \(assertionID, privacy: .public): \(result, privacy: .public)"
      )
    }
  }
}
