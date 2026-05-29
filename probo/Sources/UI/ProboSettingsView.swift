import SwiftUI

struct ProboSettingsView: View {
  @Bindable var runtime: ProboRuntime

  var body: some View {
    Form {
      Section("Scrolling") {
        SettingsRow(
          title: "Wheel Step",
          description: "Lines emitted per mouse-wheel notch."
        ) {
          Picker(selection: $runtime.intensity) {
            ForEach(ScrollIntensity.allCases, id: \.self) {
              Text($0.title).tag($0)
            }
          } label: {
            Text("Wheel Step")
          }
          .labelsHidden()
        }

        SettingsToggleRow(
          title: "Option Precision",
          description: "Hold Option to emit one line per notch.",
          isOn: $runtime.isOptionPrecisionEnabled)

        SettingsToggleRow(
          title: "Terminal Optimization",
          description:
            "In terminal apps, emit one line per notch; hold Option for your wheel step.",
          isOn: $runtime.isTerminalOptimizationEnabled)

        SettingsToggleRow(
          title: "Natural Direction",
          description: "Match trackpad scrolling direction.",
          isOn: $runtime.isTrackpadStyleScrollingEnabled)
      }

      Section("Input") {
        SettingsToggleRow(
          title: "Look Up",
          description: "Map mouse button 4 to Look Up.",
          isOn: $runtime.isLookUpEnabled)
      }

      Section("Power") {
        SettingsToggleRow(
          title: "Prevent Automatic Sleep",
          description:
            "Keep your Mac awake while Probo is enabled. Display sleep, lid close, and manual sleep are still allowed.",
          isOn: $runtime.preventsAutomaticSleep)
      }

      Section("Accessibility") {
        SettingsRow(title: "Permission") {
          Label(
            runtime.accessibilityTrusted ? "Granted" : "Required",
            systemImage: runtime.accessibilityTrusted
              ? "checkmark.circle.fill" : "xmark.circle.fill"
          )
          .foregroundStyle(runtime.accessibilityTrusted ? .green : .red)
        }

        if !runtime.accessibilityTrusted {
          SettingsRow(
            title: "Accessibility Access",
            description: "Open System Settings to grant event monitoring access."
          ) {
            Button("Request Access...") {
              runtime.requestAccessibilityAccess()
            }
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

private struct SettingsRow<Content: View>: View {
  let title: String
  let description: String?
  @ViewBuilder let content: Content

  init(
    title: String,
    description: String? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.description = description
    self.content = content()
  }

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)

        if let description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      content
    }
  }
}

private struct SettingsToggleRow: View {
  let title: String
  let description: String
  @Binding var isOn: Bool

  var body: some View {
    SettingsRow(title: title, description: description) {
      Toggle(isOn: $isOn) {
        Text(title)
      }
      .labelsHidden()
    }
  }
}
