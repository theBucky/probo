import AppKit
import ProboCore
import SwiftUI

@main
struct ProboApp: App {
  @State private var runtime: Runtime

  init() {
    let runtime = Runtime()
    runtime.refreshAccessibility()
    self.runtime = runtime
  }

  var body: some Scene {
    MenuBarExtra("Probo", systemImage: runtime.status.symbolName) {
      MenuContent(runtime: runtime)
    }

    Settings {
      SettingsView(runtime: runtime)
        .onAppear {
          runtime.refreshAccessibility()
        }
        .onDisappear {
          NSApp.setActivationPolicy(.accessory)
        }
    }
    .windowResizability(.contentSize)
  }
}

private struct MenuContent: View {
  @Bindable var runtime: Runtime
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Toggle("Enabled", isOn: $runtime.configuration.isEnabled)
    Toggle("Start at Login", isOn: $runtime.startAtLoginEnabled)

    Divider()

    if runtime.status == .needsAccessibility {
      Button("Grant Accessibility Access...") {
        runtime.requestAccessibilityAccess()
      }
    }
    if runtime.status == .tapFailed {
      Button("Retry Event Tap") {
        runtime.refreshAccessibility()
      }
    }
    Button("Settings...") {
      // Accessory apps must become regular and active before the window exists, or AppKit orders it behind other apps.
      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)
      openSettings()
    }

    Divider()

    Button("Quit Probo") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}

extension RuntimeStatus {
  fileprivate var symbolName: String {
    switch self {
    case .idle: "computermouse"
    case .needsAccessibility: "exclamationmark.triangle.fill"
    case .active: "computermouse.fill"
    case .tapFailed: "exclamationmark.octagon.fill"
    }
  }
}
