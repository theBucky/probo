import AppKit
import SwiftUI

struct ProboMenuView: View {
  @Bindable var model: ProboModel
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Toggle("Enabled", isOn: enabled)

    if !model.accessibilityTrusted {
      Button("Request Accessibility Access...") {
        model.requestAccessibilityAccess()
      }
    }

    Divider()

    Button("Settings...") {
      openSettings()
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
    .keyboardShortcut(",", modifiers: .command)

    Toggle("Start at Login", isOn: startAtLogin)

    Divider()

    Button("Quit Probo") {
      model.quit()
    }
    .keyboardShortcut("q", modifiers: .command)
  }

  private var enabled: Binding<Bool> {
    Binding(
      get: { model.configuration.isEnabled },
      set: { model.setEnabled($0) }
    )
  }

  private var startAtLogin: Binding<Bool> {
    Binding(
      get: { model.startAtLoginEnabled },
      set: { model.setStartAtLoginEnabled($0) }
    )
  }
}
