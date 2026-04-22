import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let configurationStore = AppConfigurationStore()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private lazy var eventTapController = EventTapController()
    private let statusMenuController = StatusMenuController()

    private var configuration = AppConfiguration(isEnabled: true, intensity: .slow)
    private var tapStatus = EventTapController.Status(isInstalled: false, isEnabled: false)
    private var lastMenuState: StatusMenuState?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configuration = configurationStore.load()
        eventTapController.intensity = configuration.intensity

        eventTapController.onStatusChange = { [weak self] status in
            self?.tapStatus = status
            self?.renderStatusMenu()
        }

        statusMenuController.onToggleEnabled = { [weak self] in
            self?.toggleEnabled()
        }
        statusMenuController.onSelectIntensity = { [weak self] intensity in
            self?.selectIntensity(intensity)
        }
        statusMenuController.onToggleStartAtLogin = { [weak self] in
            self?.toggleStartAtLogin()
        }
        statusMenuController.onGrantAccessibilityAccess = { [weak self] in
            self?.requestAccessibilityAccess()
        }
        statusMenuController.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        refreshRuntime(promptForAccessibility: configuration.isEnabled)
        startPermissionMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        eventTapController.teardown()
    }

    private func toggleEnabled() {
        configuration.isEnabled.toggle()
        configurationStore.save(configuration)
        refreshRuntime(promptForAccessibility: configuration.isEnabled)
    }

    private func selectIntensity(_ intensity: ScrollIntensity) {
        guard configuration.intensity != intensity else {
            return
        }

        configuration.intensity = intensity
        configurationStore.save(configuration)
        eventTapController.intensity = intensity
        renderStatusMenu()
    }

    private func toggleStartAtLogin() {
        let nextValue = !launchAtLoginManager.isEnabled
        try? launchAtLoginManager.setEnabled(nextValue)
        renderStatusMenu()
    }

    private func requestAccessibilityAccess() {
        _ = AccessibilityPermission.isTrusted(prompt: true)
        refreshRuntime(promptForAccessibility: false)
    }

    private func refreshRuntime(promptForAccessibility: Bool) {
        let accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: promptForAccessibility)
        eventTapController.setEnabled(configuration.isEnabled && accessibilityTrusted)
    }

    private func renderStatusMenu() {
        let state = StatusMenuState(
            configuration: configuration,
            startAtLoginEnabled: launchAtLoginManager.isEnabled,
            accessibilityTrusted: AccessibilityPermission.isTrusted(prompt: false),
            tapStatus: tapStatus
        )

        guard lastMenuState != state else {
            return
        }

        lastMenuState = state
        statusMenuController.render(state)
    }

    private func startPermissionMonitor() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            let accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
            if accessibilityTrusted && self.configuration.isEnabled && !self.tapStatus.isEnabled {
                self.refreshRuntime(promptForAccessibility: false)
            } else {
                self.renderStatusMenu()
            }
        }
    }
}
