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
      "given automatic sleep prevention is active when deinitialized then it releases the assertion"
  ) {
    let driver = PowerAssertionDriver(assertionID: 42)
    do {
      let controller = AutomaticSleepPreventionController(
        createAssertion: { driver.create() },
        releaseAssertion: { driver.release($0) }
      )
      controller.setEnabled(true)
    }

    try expectEqual(driver.createdCount, 1, "active controller should create one assertion")
    try expectEqual(
      driver.releasedAssertions,
      [42],
      "deinitialized controller should release the active assertion"
    )
  },
]

private final class PowerAssertionDriver {
  private let assertionID: UInt32
  private(set) var createdCount = 0
  private(set) var releasedAssertions: [UInt32] = []

  init(assertionID: UInt32) {
    self.assertionID = assertionID
  }

  func create() -> UInt32? {
    createdCount += 1
    return assertionID
  }

  func release(_ assertionID: UInt32) {
    releasedAssertions.append(assertionID)
  }
}
