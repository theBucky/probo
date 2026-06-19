import AppKit
import SwiftUI

@MainActor
package final class ProboSettingsViewController: NSHostingController<ProboSettingsView> {
  private let runtime: ProboRuntime

  package init(runtime: ProboRuntime) {
    self.runtime = runtime
    super.init(rootView: ProboSettingsView(runtime: runtime))
    sizingOptions = [.preferredContentSize]
    preferredContentSize = fittingContentSize
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  package func reload() {
    rootView = ProboSettingsView(runtime: runtime)
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

  private enum ToggleSetting {
    case optionPrecision
    case terminalOptimization
    case naturalDirection
    case lookUp
    case preventAutomaticSleep

    var title: String {
      switch self {
      case .optionPrecision: "Option Precision"
      case .terminalOptimization: "Terminal Optimization"
      case .naturalDirection: "Natural Direction"
      case .lookUp: "Look Up"
      case .preventAutomaticSleep: "Prevent Automatic Sleep"
      }
    }

    var description: String {
      switch self {
      case .optionPrecision:
        "Hold Option to emit one line per notch."
      case .terminalOptimization:
        "In terminal apps, emit one line per notch; hold Option for your wheel step."
      case .naturalDirection:
        "Match trackpad scrolling direction."
      case .lookUp:
        "Map mouse button 4 to Look Up."
      case .preventAutomaticSleep:
        "Keep your Mac awake while Probo is enabled. Display sleep, lid close, and manual sleep are still allowed."
      }
    }

    var keyPath: WritableKeyPath<AppConfiguration, Bool> {
      switch self {
      case .optionPrecision: \.isOptionPrecisionEnabled
      case .terminalOptimization: \.isTerminalOptimizationEnabled
      case .naturalDirection: \.isTrackpadStyleScrollingEnabled
      case .lookUp: \.isLookUpEnabled
      case .preventAutomaticSleep: \.preventsAutomaticSleep
      }
    }
  }

  private let runtime: ProboRuntime

  package init(runtime: ProboRuntime) {
    self.runtime = runtime
  }

  package var body: some View {
    Form {
      Section("Scrolling") {
        Picker("Wheel Step", selection: intensity) {
          ForEach(ScrollIntensity.allCases, id: \.self) { intensity in
            Text(intensity.title).tag(intensity)
          }
        }
        .pickerStyle(.menu)

        toggle(.optionPrecision)
        toggle(.terminalOptimization)
        toggle(.naturalDirection)
      }

      Section("Input") {
        toggle(.lookUp)
      }

      Section("Power") {
        toggle(.preventAutomaticSleep)
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

  private var intensity: Binding<ScrollIntensity> {
    Binding(
      get: { runtime.intensity },
      set: { runtime.intensity = $0 }
    )
  }

  private func toggle(_ setting: ToggleSetting) -> some View {
    Toggle(isOn: binding(for: setting)) {
      VStack(alignment: .leading, spacing: 2) {
        Text(setting.title)
        Text(setting.description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .toggleStyle(.switch)
  }

  private func binding(for setting: ToggleSetting) -> Binding<Bool> {
    Binding(
      get: { runtime[toggle: setting.keyPath] },
      set: { runtime[toggle: setting.keyPath] = $0 }
    )
  }
}

extension ScrollIntensity {
  fileprivate var title: String {
    switch self {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }
}
