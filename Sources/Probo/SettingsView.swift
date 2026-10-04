import ProboCore
import SwiftUI

struct SettingsView: View {
  @Bindable var runtime: Runtime

  var body: some View {
    Form {
      Section("Scrolling") {
        Picker("Wheel Step", selection: $runtime.configuration.input.wheelStep) {
          ForEach(WheelStep.allCases, id: \.self) { wheelStep in
            Text(wheelStep.title).tag(wheelStep)
          }
        }
        .pickerStyle(.menu)

        SettingToggle(
          title: "Option Precision",
          description: "Hold Option to emit one line per notch.",
          isOn: $runtime.configuration.input.isOptionPrecisionEnabled
        )
        SettingToggle(
          title: "Terminal Optimization",
          description:
            "In terminal apps, emit one line per notch; hold Option for your wheel step.",
          isOn: $runtime.configuration.input.isTerminalOptimizationEnabled
        )
        SettingToggle(
          title: "Natural Direction",
          description: "Match trackpad scrolling direction.",
          isOn: $runtime.configuration.input.isTrackpadStyleScrollingEnabled
        )
      }

      Section("Input") {
        SettingToggle(
          title: "Look Up",
          description: "Map mouse button 4 to Look Up.",
          isOn: $runtime.configuration.input.isLookUpEnabled
        )
      }

      Section("Power") {
        SettingToggle(
          title: "Prevent Automatic Sleep",
          description:
            "Keep your Mac awake while Probo is enabled. Display sleep, lid close, and manual sleep are still allowed.",
          isOn: $runtime.configuration.preventsIdleSleep
        )
      }

      Section("Accessibility") {
        AccessibilityStatus(runtime: runtime)
      }
    }
    .formStyle(.grouped)
    .scrollContentBackground(.hidden)
    .contentMargins(.top, 8, for: .scrollContent)
    .frame(width: 500)
    // A grouped form is scroll-backed; size it to its content and disable the leftover scroller, which macOS shows for a mouse even with nothing to scroll.
    .fixedSize(horizontal: false, vertical: true)
    .scrollDisabled(true)
    .scrollIndicators(.never)
  }
}

private struct SettingToggle: View {
  let title: LocalizedStringKey
  let description: LocalizedStringKey
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .toggleStyle(.switch)
  }
}

private struct AccessibilityStatus: View {
  let runtime: Runtime

  var body: some View {
    let trusted = runtime.accessibilityTrusted

    Label {
      Text(trusted ? "Granted" : "Required")
    } icon: {
      Image(systemName: trusted ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundStyle(trusted ? .green : .red)
    }

    if !trusted {
      Button("Request Access...") {
        runtime.requestAccessibilityAccess()
      }
    }
  }
}

extension WheelStep {
  fileprivate var title: LocalizedStringResource {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }
}
