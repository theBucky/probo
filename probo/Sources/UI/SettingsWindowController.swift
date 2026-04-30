import AppKit

struct SettingsWindowState: Equatable {
  var configuration: AppConfiguration
}

private enum SettingsLayout {
  static let windowWidth: CGFloat = 620
  static let contentHeight: CGFloat = 324
  static let bodyInsetX: CGFloat = 24
  static let bodyInsetY: CGFloat = 24
  static let groupCornerRadius: CGFloat = 14
  static let rowHeight: CGFloat = 68
  static let rowInsetX: CGFloat = 18
  static let rowColumnSpacing: CGFloat = 16
  static let textSpacing: CGFloat = 2
  static let textWidth: CGFloat = 300
  static let iconSize: CGFloat = 40
  static let iconCornerRadius: CGFloat = 9
  static let iconSymbolPointSize: CGFloat = 23
  static let dropdownWidth: CGFloat = 132
  static let accessoryWidth: CGFloat = 132
  static var separatorInsetX: CGFloat { rowInsetX + iconSize + rowColumnSpacing }
}

@MainActor
final class SettingsWindowController: NSWindowController {
  var onSelectIntensity: ((ScrollIntensity) -> Void)?
  var onToggleLookUp: (() -> Void)?
  var onTogglePrecisionScroll: (() -> Void)?
  var onToggleMouseWheelDirection: (() -> Void)?

  private let intensityButton = NSPopUpButton(
    frame: .zero,
    pullsDown: false
  )
  private let lookUpSwitch = NSSwitch()
  private let precisionScrollSwitch = NSSwitch()
  private let mouseWheelDirectionSwitch = NSSwitch()

  init() {
    let window = NSWindow(
      contentRect: NSRect(
        x: 0,
        y: 0,
        width: SettingsLayout.windowWidth,
        height: SettingsLayout.contentHeight
      ),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.isReleasedWhenClosed = false
    window.title = "Probo Settings"
    window.titlebarAppearsTransparent = true

    super.init(window: window)

    configureIntensityButton()
    configureSwitches()
    lookUpSwitch.action = #selector(toggleLookUp)
    precisionScrollSwitch.action = #selector(togglePrecisionScroll)
    mouseWheelDirectionSwitch.action = #selector(toggleMouseWheelDirection)

    window.contentView = makeContentView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    guard let window else { return }
    if !window.isVisible {
      window.center()
    }
    showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func render(_ state: SettingsWindowState) {
    intensityButton.selectItem(withTag: state.configuration.intensity.rawValue)
    lookUpSwitch.state = state.configuration.isLookUpEnabled ? .on : .off
    precisionScrollSwitch.state =
      state.configuration.isPrecisionScrollEnabled ? .on : .off
    mouseWheelDirectionSwitch.state =
      state.configuration.isTrackpadStyleScrollingEnabled ? .on : .off
  }

  private func configureIntensityButton() {
    for intensity in ScrollIntensity.allCases {
      intensityButton.addItem(withTitle: title(for: intensity))
      intensityButton.lastItem?.tag = intensity.rawValue
    }
    intensityButton.target = self
    intensityButton.action = #selector(selectIntensity)
    intensityButton.controlSize = .regular
    intensityButton.widthAnchor.constraint(equalToConstant: SettingsLayout.dropdownWidth).isActive =
      true
  }

  private func configureSwitches() {
    for control in [lookUpSwitch, precisionScrollSwitch, mouseWheelDirectionSwitch] {
      control.target = self
      control.controlSize = .mini
    }
  }

  private func makeContentView() -> NSView {
    let contentView = NSView()
    let group = settingsGroup()
    group.translatesAutoresizingMaskIntoConstraints = false

    contentView.addSubview(group)

    NSLayoutConstraint.activate([
      group.leadingAnchor.constraint(
        equalTo: contentView.leadingAnchor, constant: SettingsLayout.bodyInsetX),
      group.trailingAnchor.constraint(
        equalTo: contentView.trailingAnchor, constant: -SettingsLayout.bodyInsetX),
      group.topAnchor.constraint(
        equalTo: contentView.topAnchor, constant: SettingsLayout.bodyInsetY),
    ])

    return contentView
  }

  private func settingsGroup() -> NSView {
    let group = NSBox()
    group.boxType = .custom
    group.borderWidth = 0
    group.fillColor = .controlBackgroundColor
    group.cornerRadius = SettingsLayout.groupCornerRadius

    let stack = NSStackView(views: [
      settingRow(
        symbolName: "gauge.with.dots.needle.bottom.50percent",
        title: "Wheel Step",
        detail: "Choose the fixed line step emitted for each mouse-wheel notch.",
        accessory: intensityButton
      ),
      separator(),
      settingRow(
        symbolName: "text.magnifyingglass",
        title: "Look Up",
        detail: "Map mouse button 4 to macOS Look Up.",
        accessory: lookUpSwitch
      ),
      separator(),
      settingRow(
        symbolName: "line.3.horizontal.decrease.circle",
        title: "Precision Scrolling",
        detail: "Hold Option to emit one line per wheel notch.",
        accessory: precisionScrollSwitch
      ),
      separator(),
      settingRow(
        symbolName: "arrow.up.arrow.down",
        title: "Mouse Wheel Direction",
        detail: "Match trackpad-style scrolling direction.",
        accessory: mouseWheelDirectionSwitch
      ),
    ])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .width
    stack.spacing = 0

    group.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: group.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: group.trailingAnchor),
      stack.topAnchor.constraint(equalTo: group.topAnchor),
      stack.bottomAnchor.constraint(equalTo: group.bottomAnchor),
    ])

    return group
  }

  private func settingRow(
    symbolName: String,
    title: String,
    detail: String,
    accessory: NSView
  ) -> NSView {
    let spacer = NSView()
    spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

    let row = NSStackView(views: [
      icon(symbolName: symbolName, accessibilityDescription: title),
      textStack(title: title, detail: detail),
      spacer,
      accessoryContainer(accessory),
    ])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = SettingsLayout.rowColumnSpacing
    row.edgeInsets = NSEdgeInsets(
      top: 0,
      left: SettingsLayout.rowInsetX,
      bottom: 0,
      right: SettingsLayout.rowInsetX
    )
    row.heightAnchor.constraint(equalToConstant: SettingsLayout.rowHeight).isActive = true
    return row
  }

  private func textStack(title: String, detail: String) -> NSView {
    let stack = NSStackView(views: [titleLabel(title), caption(detail)])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = SettingsLayout.textSpacing
    return stack
  }

  private func titleLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: NSFont.systemFontSize)
    label.textColor = .labelColor
    label.lineBreakMode = .byTruncatingTail
    label.widthAnchor.constraint(equalToConstant: SettingsLayout.textWidth).isActive = true
    return label
  }

  private func caption(_ text: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.preferredMaxLayoutWidth = SettingsLayout.textWidth
    label.lineBreakMode = .byTruncatingTail
    label.maximumNumberOfLines = 1
    return label
  }

  private func icon(symbolName: String, accessibilityDescription: String) -> NSView {
    let container = NSBox()
    container.boxType = .custom
    container.borderWidth = 0
    container.fillColor = .windowBackgroundColor
    container.cornerRadius = SettingsLayout.iconCornerRadius

    let imageView = NSImageView()
    imageView.translatesAutoresizingMaskIntoConstraints = false
    imageView.image = NSImage(
      systemSymbolName: symbolName,
      accessibilityDescription: accessibilityDescription
    )
    imageView.symbolConfiguration = NSImage.SymbolConfiguration(
      pointSize: SettingsLayout.iconSymbolPointSize,
      weight: .regular
    )
    imageView.contentTintColor = .controlAccentColor

    container.addSubview(imageView)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: SettingsLayout.iconSize),
      container.heightAnchor.constraint(equalToConstant: SettingsLayout.iconSize),
      imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    return container
  }

  private func accessoryContainer(_ accessory: NSView) -> NSView {
    let container = NSView()
    accessory.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(accessory)

    NSLayoutConstraint.activate([
      container.widthAnchor.constraint(equalToConstant: SettingsLayout.accessoryWidth),
      accessory.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      accessory.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    return container
  }

  private func separator() -> NSView {
    let container = NSView()
    let rule = NSBox()
    rule.translatesAutoresizingMaskIntoConstraints = false
    rule.boxType = .separator
    container.addSubview(rule)

    NSLayoutConstraint.activate([
      container.heightAnchor.constraint(equalToConstant: 1),
      rule.leadingAnchor.constraint(
        equalTo: container.leadingAnchor, constant: SettingsLayout.separatorInsetX),
      rule.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      rule.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    return container
  }

  private func title(for intensity: ScrollIntensity) -> String {
    switch intensity {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }

  @objc private func selectIntensity() {
    onSelectIntensity?(ScrollIntensity(rawValue: intensityButton.selectedTag())!)
  }

  @objc private func toggleLookUp() { onToggleLookUp?() }
  @objc private func togglePrecisionScroll() { onTogglePrecisionScroll?() }
  @objc private func toggleMouseWheelDirection() { onToggleMouseWheelDirection?() }
}
