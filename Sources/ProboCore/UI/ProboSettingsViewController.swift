import AppKit
import SwiftUI

@MainActor
package final class ProboSettingsViewController: NSHostingController<ProboSettingsView> {
  package init(runtime: Runtime) {
    super.init(rootView: ProboSettingsView(runtime: runtime))
    sizingOptions = [.preferredContentSize]
    preferredContentSize = fittingContentSize
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  private var fittingContentSize: NSSize {
    let size = sizeThatFits(
      in: NSSize(width: ProboSettingsView.contentWidth, height: CGFloat.greatestFiniteMagnitude))
    return NSSize(width: ProboSettingsView.contentWidth, height: ceil(size.height))
  }
}

@MainActor
package struct ProboSettingsView: View {
  fileprivate static let contentWidth: CGFloat = 500

  @Bindable private var runtime: Runtime

  package init(runtime: Runtime) {
    self.runtime = runtime
  }

  package var body: some View {
    Form {
      Section("Scrolling") {
        Picker("Wheel Step", selection: $runtime.configuration.wheelStep) {
          ForEach(WheelStep.allCases, id: \.self) { wheelStep in
            Text(wheelStep.title).tag(wheelStep)
          }
        }
        .pickerStyle(.menu)

        toggle(
          "Option Precision",
          "Hold Option to emit one line per notch.",
          $runtime.configuration.isOptionPrecisionEnabled
        )
        toggle(
          "Terminal Optimization",
          "In terminal apps, emit one line per notch; hold Option for your wheel step.",
          $runtime.configuration.isTerminalOptimizationEnabled
        )
        toggle(
          "Natural Direction",
          "Match trackpad scrolling direction.",
          $runtime.configuration.isTrackpadStyleScrollingEnabled
        )
      }

      Section("Input") {
        toggle("Look Up", "Map mouse button 4 to Look Up.", $runtime.configuration.isLookUpEnabled)
      }

      Section("Power") {
        toggle(
          "Prevent Automatic Sleep",
          "Keep your Mac awake while Probo is enabled. Display sleep, lid close, and manual sleep are still allowed.",
          $runtime.configuration.preventsIdleSleep
        )
      }

      Section("Accessibility") {
        Label {
          Text(runtime.accessibilityTrusted ? "Granted" : "Required")
        } icon: {
          Image(
            systemName: runtime.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
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
    .scrollContentBackground(.hidden)
    .contentMargins(.top, 8, for: .scrollContent)
    .frame(width: Self.contentWidth)
  }

  private func toggle(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View
  {
    Toggle(isOn: binding) {
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

extension WheelStep {
  fileprivate var title: String {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }
}
