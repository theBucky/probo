import Testing

@testable import ProboCore

@Suite("Runtime")
struct RuntimeTests {
  @Test("missing accessibility keeps tap inactive")
  func missingAccessibility() {
    let plan = SystemPlan(configuration: AppConfiguration(), accessibilityTrusted: false)

    #expect(plan.tapActive == false)
    #expect(plan.frontmostMonitorActive == false)
    #expect(plan.preventsIdleSleep == false)
  }

  @Test("trusted enabled configuration activates tap and terminal monitor")
  func trustedEnabled() {
    let plan = SystemPlan(configuration: AppConfiguration(), accessibilityTrusted: true)

    #expect(plan.tapActive)
    #expect(plan.frontmostMonitorActive)
  }

  @Test("disabled runtime stops tap and idle sleep prevention")
  func disabledRuntime() {
    let configuration = AppConfiguration(isEnabled: false, preventsIdleSleep: true)
    let plan = SystemPlan(configuration: configuration, accessibilityTrusted: true)

    #expect(plan.tapActive == false)
    #expect(plan.frontmostMonitorActive == false)
    #expect(plan.preventsIdleSleep == false)
  }

  @Test("enabled idle sleep prevention is planned independently of accessibility")
  func idleSleep() {
    let configuration = AppConfiguration(preventsIdleSleep: true)
    let plan = SystemPlan(configuration: configuration, accessibilityTrusted: false)

    #expect(plan.preventsIdleSleep)
  }

  @Test("status reflects enablement, trust, and tap installation")
  func status() {
    #expect(
      RuntimeStatus(isEnabled: true, accessibilityTrusted: false, tapEnabled: false)
        == .needsAccessibility)
    #expect(RuntimeStatus(isEnabled: true, accessibilityTrusted: true, tapEnabled: true) == .active)
    #expect(RuntimeStatus(isEnabled: true, accessibilityTrusted: true, tapEnabled: false) == .idle)
    #expect(RuntimeStatus(isEnabled: false, accessibilityTrusted: true, tapEnabled: false) == .idle)
  }
}
