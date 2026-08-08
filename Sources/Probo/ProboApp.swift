import AppKit
import ProboCore
import SwiftUI

@main
struct ProboApp: App {
  @State private var runtime: Runtime

  // The launch-time accessibility query lives here, not in Runtime.init, so tests
  // constructing a Runtime never touch AX APIs (which could install a real event
  // tap when the test runner happens to be trusted).
  init() {
    let runtime = Runtime()
    runtime.refreshAccessibility()
    self.runtime = runtime
  }

  var body: some Scene {
    MenuBarExtra("Probo", systemImage: runtime.status.symbolName) {
      ProboMenu(runtime: runtime)
    }

    Settings {
      ProboSettingsView(runtime: runtime)
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

struct ProboMenu: View {
  @Bindable var runtime: Runtime
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Toggle("Enabled", isOn: $runtime.configuration.isEnabled)
    Toggle("Start at Login", isOn: $runtime.startAtLoginEnabled)

    Divider()

    if !runtime.accessibilityTrusted {
      Button("Grant Accessibility Access...") {
        runtime.requestAccessibilityAccess()
      }
    }
    Button("Settings...") {
      openSettingsWindow()
    }

    Divider()

    Button("Quit Probo") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  private func openSettingsWindow() {
    // Status-item apps run as accessory apps. Promote and activate before the
    // window exists so AppKit creates it in an active app and orders it front;
    // activating after the fact leaves it behind other apps' windows.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    openSettings()
  }
}

extension RuntimeStatus {
  fileprivate var symbolName: String {
    switch self {
    case .needsAccessibility: "exclamationmark.triangle.fill"
    case .active: "computermouse.fill"
    case .idle: "computermouse"
    }
  }
}
