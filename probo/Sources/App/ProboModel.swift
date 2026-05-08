import Observation

@MainActor
@Observable
final class ProboModel {
  var configuration = AppConfiguration.defaultValue
  var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)
  var accessibilityTrusted = false
  var startAtLoginEnabled = false

  var statusSymbolName: String {
    if configuration.isEnabled && !accessibilityTrusted { return "exclamationmark.triangle.fill" }
    if configuration.isEnabled && tapStatus.isEnabled { return "computermouse.fill" }
    return "computermouse"
  }
}
