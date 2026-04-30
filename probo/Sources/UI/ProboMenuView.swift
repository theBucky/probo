import SwiftUI

struct ProboMenuView: View {
  @Bindable var model: ProboModel

  var body: some View {
    Toggle("Enabled", isOn: enabled)
      .task { model.refreshLaunchAtLogin() }

    if !model.accessibilityTrusted {
      Button("Request Accessibility Access...") {
        model.requestAccessibilityAccess()
      }
    }

    Divider()

    SettingsLink {
      Text("Settings...")
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
