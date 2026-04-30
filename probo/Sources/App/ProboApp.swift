import SwiftUI

@main
struct ProboApp: App {
  @State private var model: ProboModel

  init() {
    let model = ProboModel()
    model.start()
    _model = State(initialValue: model)
  }

  var body: some Scene {
    MenuBarExtra {
      ProboMenuView(model: model)
    } label: {
      Label("Probo", systemImage: model.statusSymbolName)
    }
    .menuBarExtraStyle(.menu)

    Settings {
      ProboSettingsView(model: model)
    }
  }
}
