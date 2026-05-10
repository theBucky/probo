import Foundation
import IOKit.pwr_mgt
import Synchronization
import os

final class AutomaticSleepPreventionController: Sendable {
  typealias AssertionID = UInt32

  private let createAssertion: @Sendable () -> AssertionID?
  private let releaseAssertion: @Sendable (AssertionID) -> Void
  private let logger = Logger(subsystem: "com.probo.app", category: "Power")
  private let assertionID = Mutex<AssertionID?>(nil)

  init(
    createAssertion: @escaping @Sendable () -> AssertionID? =
      AutomaticSleepPreventionController.createSystemAssertion,
    releaseAssertion: @escaping @Sendable (AssertionID) -> Void =
      AutomaticSleepPreventionController.releaseSystemAssertion
  ) {
    self.createAssertion = createAssertion
    self.releaseAssertion = releaseAssertion
  }

  deinit {
    setEnabled(false)
  }

  func setEnabled(_ enabled: Bool) {
    assertionID.withLock { storedAssertionID in
      if enabled {
        guard storedAssertionID == nil else { return }
        guard let createdAssertionID = createAssertion() else {
          logger.error("failed to prevent automatic sleep")
          return
        }
        storedAssertionID = createdAssertionID
        return
      }

      guard let activeAssertionID = storedAssertionID else { return }
      releaseAssertion(activeAssertionID)
      storedAssertionID = nil
    }
  }

  private static func createSystemAssertion() -> AssertionID? {
    var assertionID = IOPMAssertionID(0)
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

  private static func releaseSystemAssertion(_ assertionID: AssertionID) {
    IOPMAssertionRelease(IOPMAssertionID(assertionID))
  }
}
