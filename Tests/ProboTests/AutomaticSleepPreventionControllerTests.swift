import Testing

@testable import ProboCore

@Suite("Automatic sleep prevention controller", .serialized)
struct AutomaticSleepPreventionControllerTests {
  @MainActor
  @Test("enabling twice creates one assertion")
  func enablingTwice() {
    let driver = PowerAssertionDriver(assertionID: 42)
    let controller = AutomaticSleepPreventionController(
      createAssertion: { driver.create() },
      releaseAssertion: { driver.release($0) }
    )

    controller.setEnabled(true)
    controller.setEnabled(true)

    #expect(driver.createdCount == 1)
    #expect(driver.releasedAssertions == [])
  }

  @MainActor
  @Test("disabling active controller releases the assertion once")
  func disablingActiveController() {
    let driver = PowerAssertionDriver(assertionID: 42)
    let controller = AutomaticSleepPreventionController(
      createAssertion: { driver.create() },
      releaseAssertion: { driver.release($0) }
    )

    controller.setEnabled(true)
    controller.setEnabled(false)
    controller.setEnabled(false)

    #expect(driver.createdCount == 1)
    #expect(driver.releasedAssertions == [42])
  }

  @MainActor
  @Test("deinitializing active controller releases the assertion")
  func deinitializingActiveController() {
    let driver = PowerAssertionDriver(assertionID: 42)
    do {
      let controller = AutomaticSleepPreventionController(
        createAssertion: { driver.create() },
        releaseAssertion: { driver.release($0) }
      )
      controller.setEnabled(true)
    }

    #expect(driver.createdCount == 1)
    #expect(driver.releasedAssertions == [42])
  }
}

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
