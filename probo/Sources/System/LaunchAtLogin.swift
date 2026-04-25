import ServiceManagement

final class LaunchAtLogin {
  private let service = SMAppService.mainApp

  var isEnabled: Bool {
    switch service.status {
    case .enabled, .requiresApproval: true
    default: false
    }
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try service.register()
    } else {
      try service.unregister()
    }
  }
}
