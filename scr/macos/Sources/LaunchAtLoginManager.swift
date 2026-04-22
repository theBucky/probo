import ServiceManagement

final class LaunchAtLoginManager {
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
