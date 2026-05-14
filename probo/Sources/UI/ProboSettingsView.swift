import SwiftUI

struct ProboSettingsView: View {
  @Bindable var runtime: ProboRuntime

  var body: some View {
    Form {
      Section("Scrolling") {
        Picker(selection: $runtime.intensity) {
          ForEach(ScrollIntensity.allCases, id: \.self) {
            Text($0.title).tag($0)
          }
        } label: {
          Text("Wheel Step")
          Text("Lines emitted per mouse-wheel notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: $runtime.isOptionPrecisionEnabled) {
          Text("Option Precision")
          Text("Hold Option to emit one line per notch.")
            .foregroundStyle(.secondary)
        }

        Toggle(isOn: $runtime.isTerminalOptimizationEnabled) {
          Text("Terminal Optimization")
          Text("In terminal apps, emit one line per notch; hold Option for your wheel step.")
            .foregroundStyle(.secondary)
        }

        Toggle(
          isOn: $runtime.isTrackpadStyleScrollingEnabled
        ) {
          Text("Natural Direction")
          Text("Match trackpad scrolling direction.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Input") {
        Toggle(isOn: $runtime.isLookUpEnabled) {
          Text("Look Up")
          Text("Map mouse button 4 to Look Up.")
            .foregroundStyle(.secondary)
        }
      }

      Section("Power") {
        Toggle(isOn: $runtime.preventsAutomaticSleep) {
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
            runtime.accessibilityTrusted ? "Granted" : "Required",
            systemImage: runtime.accessibilityTrusted
              ? "checkmark.circle.fill" : "xmark.circle.fill"
          )
          .foregroundStyle(runtime.accessibilityTrusted ? .green : .red)
        }

        if !runtime.accessibilityTrusted {
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
}
