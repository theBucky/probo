import AppKit

@MainActor
package final class ProboSettingsViewController: NSViewController {
  private enum ToggleSetting: String {
    case optionPrecision = "option-precision"
    case terminalOptimization = "terminal-optimization"
    case naturalDirection = "natural-direction"
    case lookUp = "look-up"
    case preventAutomaticSleep = "prevent-automatic-sleep"

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
  private let cardWidth: CGFloat = 380
  private let controlWidth: CGFloat = 126
  private let contentInset: CGFloat = 20
  private let cardCornerRadius: CGFloat = 10
  private let rowInsetX: CGFloat = 14
  private let rowInsetY: CGFloat = 10

  package init(runtime: ProboRuntime) {
    self.runtime = runtime
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  package override func loadView() {
    installView()
  }

  package func reload() {
    let windowFrame = view.window?.frame
    installView()
    if let windowFrame {
      view.window?.setFrame(windowFrame, display: true)
    }
  }

  private func installView() {
    let contentView = makeView()
    view = contentView
    preferredContentSize = contentView.fittingSize
  }

  private func makeView() -> NSView {
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 20
    stack.translatesAutoresizingMaskIntoConstraints = false

    stack.addArrangedSubview(
      section(
        title: "Scrolling",
        rows: [
          row(
            title: "Wheel Step",
            description: "Lines emitted per mouse-wheel notch.",
            control: wheelStepPopup()),
          toggleRow(.optionPrecision),
          toggleRow(.terminalOptimization),
          toggleRow(.naturalDirection),
        ]))

    stack.addArrangedSubview(
      section(
        title: "Input",
        rows: [
          toggleRow(.lookUp)
        ]))

    stack.addArrangedSubview(
      section(
        title: "Power",
        rows: [
          toggleRow(.preventAutomaticSleep)
        ]))

    var accessibilityRows = [
      row(title: "Permission", control: accessibilityStatus())
    ]

    if !runtime.accessibilityTrusted {
      accessibilityRows.append(
        row(
          title: "Accessibility Access",
          description: "Open System Settings to grant event monitoring access.",
          control: requestAccessButton()))
    }

    stack.addArrangedSubview(section(title: "Accessibility", rows: accessibilityRows))

    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(stack)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: cardWidth + contentInset * 2),
      stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: contentInset),
      stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -contentInset),
      stack.topAnchor.constraint(equalTo: container.topAnchor, constant: contentInset),
      stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -contentInset),
    ])

    return container
  }

  private func section(title: String, rows: [NSView]) -> NSView {
    let header = NSTextField(labelWithString: title)
    header.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    header.textColor = .secondaryLabelColor
    header.translatesAutoresizingMaskIntoConstraints = false

    let rowsStack = NSStackView()
    rowsStack.orientation = .vertical
    rowsStack.alignment = .leading
    rowsStack.spacing = 0
    rowsStack.translatesAutoresizingMaskIntoConstraints = false

    for (index, rowView) in rows.enumerated() {
      if index > 0 {
        let divider = separator()
        rowsStack.addArrangedSubview(divider)
        divider.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor).isActive = true
      }
      rowsStack.addArrangedSubview(rowView)
      rowView.trailingAnchor.constraint(equalTo: rowsStack.trailingAnchor).isActive = true
    }

    let card = NSBox()
    card.boxType = .custom
    card.titlePosition = .noTitle
    card.cornerRadius = cardCornerRadius
    card.borderWidth = 1
    card.borderColor = .separatorColor
    card.fillColor = .controlBackgroundColor
    card.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(rowsStack)

    let group = NSStackView(views: [header, card])
    group.orientation = .vertical
    group.alignment = .leading
    group.spacing = 6
    group.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
      card.widthAnchor.constraint(equalToConstant: cardWidth),
      rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
      rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
      rowsStack.topAnchor.constraint(equalTo: card.topAnchor),
      rowsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
    ])

    return group
  }

  private func separator() -> NSBox {
    let divider = NSBox()
    divider.boxType = .separator
    divider.translatesAutoresizingMaskIntoConstraints = false
    return divider
  }

  private func row(title: String, description: String? = nil, control: NSView) -> NSView {
    let titleLabel = NSTextField(labelWithString: title)
    titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
    titleLabel.lineBreakMode = .byWordWrapping
    titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

    let textStack = NSStackView(views: [titleLabel])
    textStack.orientation = .vertical
    textStack.alignment = .leading
    textStack.spacing = 2

    if let description {
      let descriptionLabel = NSTextField(wrappingLabelWithString: description)
      descriptionLabel.font = .preferredFont(forTextStyle: .caption1)
      descriptionLabel.textColor = .secondaryLabelColor
      descriptionLabel.maximumNumberOfLines = 0
      descriptionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
      textStack.addArrangedSubview(descriptionLabel)
    }

    let row = NSView()
    row.translatesAutoresizingMaskIntoConstraints = false
    textStack.translatesAutoresizingMaskIntoConstraints = false
    control.translatesAutoresizingMaskIntoConstraints = false
    row.addSubview(textStack)
    row.addSubview(control)

    // Controls right-align in a fixed-width column so titles share one trailing edge across rows.
    NSLayoutConstraint.activate([
      textStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: rowInsetX),
      textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: rowInsetY),
      textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -rowInsetY),
      textStack.trailingAnchor.constraint(
        equalTo: row.trailingAnchor, constant: -(rowInsetX + controlWidth + 16)),
      control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -rowInsetX),
      control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
    ])

    return row
  }

  private func toggleRow(_ setting: ToggleSetting) -> NSView {
    let control = NSButton(
      checkboxWithTitle: "", target: self, action: #selector(toggleSetting(_:)))
    control.identifier = NSUserInterfaceItemIdentifier(setting.rawValue)
    control.setAccessibilityLabel(setting.title)
    control.state = runtime[toggle: setting.keyPath] ? .on : .off
    control.setContentHuggingPriority(.required, for: .horizontal)
    return row(title: setting.title, description: setting.description, control: control)
  }

  private func wheelStepPopup() -> NSPopUpButton {
    let popup = NSPopUpButton()
    popup.identifier = NSUserInterfaceItemIdentifier("wheel-step")
    for intensity in ScrollIntensity.allCases {
      popup.addItem(withTitle: intensity.title)
      popup.lastItem?.tag = intensity.rawValue
    }
    popup.selectItem(withTag: runtime.intensity.rawValue)
    popup.target = self
    popup.action = #selector(changeWheelStep(_:))
    popup.setContentHuggingPriority(.required, for: .horizontal)
    popup.widthAnchor.constraint(equalToConstant: controlWidth).isActive = true
    return popup
  }

  private func accessibilityStatus() -> NSView {
    let symbolName = runtime.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill"
    // systemSymbolName resolves to nil under headless rendering (CI); fall back to an empty image.
    let imageView = NSImageView(
      image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage())
    imageView.contentTintColor = runtime.accessibilityTrusted ? .systemGreen : .systemRed
    imageView.symbolConfiguration = .init(pointSize: 14, weight: .semibold)

    let label = NSTextField(labelWithString: runtime.accessibilityTrusted ? "Granted" : "Required")
    label.identifier = NSUserInterfaceItemIdentifier("accessibility-permission")
    label.textColor = runtime.accessibilityTrusted ? .systemGreen : .systemRed

    let stack = NSStackView(views: [imageView, label])
    stack.orientation = .horizontal
    stack.alignment = .centerY
    stack.spacing = 5
    stack.setContentHuggingPriority(.required, for: .horizontal)
    return stack
  }

  private func requestAccessButton() -> NSButton {
    let button = NSButton(
      title: "Request Access...", target: self, action: #selector(requestAccess))
    button.identifier = NSUserInterfaceItemIdentifier("request-access")
    button.bezelStyle = .rounded
    button.setContentHuggingPriority(.required, for: .horizontal)
    return button
  }

  @objc private func changeWheelStep(_ sender: NSPopUpButton) {
    runtime.intensity = ScrollIntensity(rawValue: sender.selectedTag())!
  }

  @objc private func toggleSetting(_ sender: NSButton) {
    let setting = ToggleSetting(rawValue: sender.identifier!.rawValue)!
    runtime[toggle: setting.keyPath] = sender.state == .on
  }

  @objc private func requestAccess() {
    runtime.requestAccessibilityAccess()
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
