import SwiftUI

struct ProboSettingsView: View {
  let model: ProboModel
  let runtime: ProboRuntime

  var body: some View {
    Form {
      Section("Scrolling") {
        Picker(selection: bind(\.intensity)) {
          ForEach(ScrollIntensity.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        } label: {
          Text("Wheel Step")
          Text("Lines emitted per mouse-wheel notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: bind(\.isOptionPrecisionEnabled)) {
          Text("Option Precision")
          Text("Hold Option to emit one line per notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: bind(\.isTerminalDefaultPrecisionEnabled)) {
          Text("Default Precision in Terminals")
          Text("Emit one line per notch in terminal apps; hold Option for your wheel step.")
            .foregroundStyle(.secondary)
        }

        Toggle(
          isOn: bind(\.isTrackpadStyleScrollingEnabled)
        ) {
          Text("Natural Direction")
          Text("Match trackpad scrolling direction.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Input") {
        Toggle(isOn: bind(\.isLookUpEnabled)) {
          Text("Look Up")
          Text("Map mouse button 4 to Look Up.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Power") {
        Toggle(isOn: bind(\.preventsAutomaticSleep)) {
          Text("Prevent Automatic Sleep")
          Text(
            "Keep your Mac awake while Probo is enabled. Display sleep, lid close, and manual sleep are still allowed."
          )
          .foregroundStyle(.secondary)
        }
      }

      Section("Accessibility") {
        LabeledContent("Permission") {
          Label(
            model.accessibilityTrusted ? "Granted" : "Required",
            systemImage: model.accessibilityTrusted
              ? "checkmark.circle.fill" : "xmark.circle.fill"
          )
          .foregroundStyle(model.accessibilityTrusted ? .green : .red)
        }

        if !model.accessibilityTrusted {
          Button("Request Access...") {
            runtime.requestAccessibilityAccess()
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 420)
    .scrollDisabled(true)
    .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
  }

  private func bind<V>(
    _ keyPath: WritableKeyPath<AppConfiguration, V>
  ) -> Binding<V> {
    Binding(
      get: { model.configuration[keyPath: keyPath] },
      set: { value in
        runtime.updateConfiguration { $0[keyPath: keyPath] = value }
      }
    )
  }
}
