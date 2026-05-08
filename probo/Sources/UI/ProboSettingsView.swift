import SwiftUI

struct ProboSettingsView: View {
  let model: ProboModel

  var body: some View {
    Form {
      Section("Scrolling") {
        Picker(selection: bind(\.intensity, model.setIntensity)) {
          ForEach(ScrollIntensity.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        } label: {
          Text("Wheel Step")
          Text("Lines emitted per mouse-wheel notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: bind(\.isPrecisionScrollEnabled, model.setPrecisionScrollEnabled)) {
          Text("Precision Scrolling")
          Text("Hold Option to emit one line per notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: bind(\.isTerminalPrecisionEnabled, model.setTerminalPrecisionEnabled)) {
          Text("Precision in Terminals")
          Text("Emit one line per notch in terminal apps; hold Option for your wheel step.")
            .foregroundStyle(.secondary)
        }

        Toggle(
          isOn: bind(\.isTrackpadStyleScrollingEnabled, model.setTrackpadStyleScrollingEnabled)
        ) {
          Text("Natural Direction")
          Text("Match trackpad scrolling direction.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Input") {
        Toggle(isOn: bind(\.isLookUpEnabled, model.setLookUpEnabled)) {
          Text("Look Up")
          Text("Map mouse button 4 to Look Up.")
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
            model.requestAccessibilityAccess()
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
    _ keyPath: KeyPath<AppConfiguration, V>,
    _ setter: @escaping @MainActor (V) -> Void
  ) -> Binding<V> {
    Binding(
      get: { model.configuration[keyPath: keyPath] },
      set: setter
    )
  }
}
