import SwiftUI

struct ProboSettingsView: View {
  let model: ProboModel

  var body: some View {
    Form {
      Section("Scrolling") {
        Picker(selection: intensity) {
          ForEach(ScrollIntensity.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        } label: {
          Text("Wheel Step")
          Text("Lines emitted per mouse-wheel notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: precisionScroll) {
          Text("Precision Scrolling")
          Text("Hold Option to emit one line per notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: trackpadStyleScrolling) {
          Text("Natural Direction")
          Text("Match trackpad scrolling direction.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Input") {
        Toggle(isOn: lookUp) {
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
    .task { model.refreshLaunchAtLogin() }
  }

  private var intensity: Binding<ScrollIntensity> {
    Binding(
      get: { model.configuration.intensity },
      set: { model.setIntensity($0) }
    )
  }

  private var lookUp: Binding<Bool> {
    Binding(
      get: { model.configuration.isLookUpEnabled },
      set: { model.setLookUpEnabled($0) }
    )
  }

  private var precisionScroll: Binding<Bool> {
    Binding(
      get: { model.configuration.isPrecisionScrollEnabled },
      set: { model.setPrecisionScrollEnabled($0) }
    )
  }

  private var trackpadStyleScrolling: Binding<Bool> {
    Binding(
      get: { model.configuration.isTrackpadStyleScrollingEnabled },
      set: { model.setTrackpadStyleScrollingEnabled($0) }
    )
  }
}
