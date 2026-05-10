import Foundation

let automaticSleepPreventionControllerTests: [TestCase] = [
  TestCase(
    behavior:
      "given automatic sleep prevention is enabled twice then it creates one assertion"
  ) {
    let driver = PowerAssertionDriver(assertionID: 42)
    let controller = AutomaticSleepPreventionController(
      createAssertion: { driver.create() },
      releaseAssertion: { driver.release($0) }
    )

    controller.setEnabled(true)
    controller.setEnabled(true)

    try expectEqual(driver.createdCount, 1, "enabled controller should create one assertion")
    try expectEqual(
      driver.releasedAssertions,
      [],
      "enabled controller should keep the assertion active"
    )
  },

  TestCase(
    behavior:
      "given automatic sleep prevention is active when disabled then it releases the assertion"
  ) {
    let driver = PowerAssertionDriver(assertionID: 42)
    let controller = AutomaticSleepPreventionController(
      createAssertion: { driver.create() },
      releaseAssertion: { driver.release($0) }
    )

    controller.setEnabled(true)
    controller.setEnabled(false)
    controller.setEnabled(false)

    try expectEqual(driver.createdCount, 1, "active controller should keep one assertion")
    try expectEqual(
      driver.releasedAssertions,
      [42],
      "disabled controller should release the active assertion once"
    )
  },

  TestCase(
    behavior:
      "given concurrent automatic sleep prevention enables then it creates one assertion"
  ) {
    let driver = PowerAssertionDriver(assertionID: 42, creationDelay: 0.01)
    let controller = AutomaticSleepPreventionController(
      createAssertion: { driver.create() },
      releaseAssertion: { driver.release($0) }
    )

    DispatchQueue.concurrentPerform(iterations: 20) { _ in
      controller.setEnabled(true)
    }

    try expectEqual(driver.createdCount, 1, "concurrent enables should create one assertion")
    try expectEqual(
      driver.releasedAssertions,
      [],
      "concurrent enables should keep the assertion active"
    )
  },
]

private final class PowerAssertionDriver: @unchecked Sendable {
  private let assertionID: UInt32
  private let creationDelay: TimeInterval
  private let lock = NSLock()
  private var mutableCreatedCount = 0
  private var mutableReleasedAssertions: [UInt32] = []

  var createdCount: Int {
    lock.withLock { mutableCreatedCount }
  }

  var releasedAssertions: [UInt32] {
    lock.withLock { mutableReleasedAssertions }
  }

  init(assertionID: UInt32, creationDelay: TimeInterval = 0) {
    self.assertionID = assertionID
    self.creationDelay = creationDelay
  }

  func create() -> UInt32? {
    if creationDelay > 0 {
      Thread.sleep(forTimeInterval: creationDelay)
    }
    lock.withLock {
      mutableCreatedCount += 1
    }
    return assertionID
  }

  func release(_ assertionID: UInt32) {
    lock.withLock {
      mutableReleasedAssertions.append(assertionID)
    }
  }
}
