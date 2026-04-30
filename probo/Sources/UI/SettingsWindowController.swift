import AppKit

struct SettingsWindowState: Equatable {
  var configuration: AppConfiguration
}

private enum SettingsPane: CaseIterable {
  case intensity, misc

  var identifier: NSToolbarItem.Identifier {
    switch self {
    case .intensity: .init("com.probo.settings.intensity")
    case .misc: .init("com.probo.settings.misc")
    }
  }

  var title: String {
    switch self {
    case .intensity: "Intensity"
    case .misc: "Misc"
    }
  }

  var symbolName: String {
    switch self {
    case .intensity: "gauge.with.dots.needle.bottom.50percent"
    case .misc: "switch.2"
    }
  }

  static func pane(for identifier: NSToolbarItem.Identifier) -> Self {
    allCases.first { $0.identifier == identifier }!
  }
}

private enum SettingsLayout {
  static let windowWidth: CGFloat = 460
  static let contentHeight: CGFloat = 228
  static let bodyInsetX: CGFloat = 28
  static let bodyInsetY: CGFloat = 26
  static let rowSpacing: CGFloat = 16
  static let rowColumnSpacing: CGFloat = 16
  static let textSpacing: CGFloat = 3
  static let textWidth: CGFloat = 220
  static let dropdownWidth: CGFloat = 150
}

@MainActor
final class SettingsWindowController: NSWindowController, NSToolbarDelegate {
  var onSelectIntensity: ((ScrollIntensity) -> Void)?
  var onToggleLookUp: (() -> Void)?
  var onTogglePrecisionScroll: (() -> Void)?
  var onToggleMouseWheelDirection: (() -> Void)?

  private let contentContainer = NSView()
  private let intensityButton = NSPopUpButton(
    frame: .zero,
    pullsDown: false
  )
  private let lookUpSwitch = NSSwitch()
  private let precisionScrollSwitch = NSSwitch()
  private let mouseWheelDirectionSwitch = NSSwitch()

  private var selectedPane = SettingsPane.intensity

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
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .preference

    super.init(window: window)

    for control in [
      intensityButton, lookUpSwitch, precisionScrollSwitch, mouseWheelDirectionSwitch,
    ] {
      control.target = self
    }
    configureIntensityButton()
    lookUpSwitch.action = #selector(toggleLookUp)
    precisionScrollSwitch.action = #selector(togglePrecisionScroll)
    mouseWheelDirectionSwitch.action = #selector(toggleMouseWheelDirection)

    configureToolbar()
    configureContentContainer()
    showPane(.intensity)
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

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    SettingsPane.allCases.map(\.identifier)
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarAllowedItemIdentifiers(toolbar)
  }

  func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarAllowedItemIdentifiers(toolbar)
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    let pane = SettingsPane.pane(for: itemIdentifier)
    let item = NSToolbarItem(itemIdentifier: itemIdentifier)
    item.label = pane.title
    item.paletteLabel = pane.title
    item.image = NSImage(systemSymbolName: pane.symbolName, accessibilityDescription: pane.title)
    item.target = self
    item.action = #selector(selectPaneFromToolbar)
    return item
  }

  private func configureToolbar() {
    let toolbar = NSToolbar(identifier: "com.probo.settings.toolbar")
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .regular
    toolbar.selectedItemIdentifier = selectedPane.identifier
    window?.toolbar = toolbar
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

  private func configureContentContainer() {
    let contentView = NSView()
    contentContainer.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(contentContainer)
    window?.contentView = contentView

    NSLayoutConstraint.activate([
      contentContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      contentContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      contentContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
      contentContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
    ])
  }

  private func showPane(_ pane: SettingsPane) {
    guard pane != selectedPane || contentContainer.subviews.isEmpty else { return }
    selectedPane = pane
    window?.title = pane.title
    window?.toolbar?.selectedItemIdentifier = pane.identifier

    contentContainer.subviews.forEach { $0.removeFromSuperview() }

    let paneView =
      switch pane {
      case .intensity: makeIntensityPane()
      case .misc: makeMiscPane()
      }
    paneView.translatesAutoresizingMaskIntoConstraints = false
    contentContainer.addSubview(paneView)

    NSLayoutConstraint.activate([
      paneView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
      paneView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
      paneView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
      paneView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
    ])

    window?.setContentSize(
      NSSize(width: SettingsLayout.windowWidth, height: SettingsLayout.contentHeight))
  }

  private func makeIntensityPane() -> NSView {
    paneBody(views: [
      settingRow(
        title: "wheel step",
        accessory: intensityButton
      )
    ])
  }

  private func makeMiscPane() -> NSView {
    paneBody(views: [
      settingRow(
        title: "look up",
        detail: "map mouse button 4 to macos look up.",
        accessory: lookUpSwitch
      ),
      settingRow(
        title: "precise scrolling",
        detail: "hold option to emit one line per wheel notch.",
        accessory: precisionScrollSwitch
      ),
      settingRow(
        title: "mouse wheel direction",
        detail: "match trackpad-style scrolling direction.",
        accessory: mouseWheelDirectionSwitch
      ),
    ])
  }

  private func paneBody(views: [NSView]) -> NSView {
    let stack = NSStackView(views: views)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = SettingsLayout.rowSpacing

    let body = NSView()
    body.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(
        equalTo: body.leadingAnchor,
        constant: SettingsLayout.bodyInsetX
      ),
      stack.trailingAnchor.constraint(
        lessThanOrEqualTo: body.trailingAnchor,
        constant: -SettingsLayout.bodyInsetX
      ),
      stack.topAnchor.constraint(equalTo: body.topAnchor, constant: SettingsLayout.bodyInsetY),
    ])

    return body
  }

  private func settingRow(title: String, detail: String? = nil, accessory: NSView) -> NSView {
    let row = NSStackView(views: [textStack(title: title, detail: detail), accessory])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = SettingsLayout.rowColumnSpacing
    return row
  }

  private func textStack(title: String, detail: String?) -> NSView {
    var views: [NSView] = [titleLabel(title)]
    if let detail {
      views.append(caption(detail))
    }

    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = SettingsLayout.textSpacing
    return stack
  }

  private func titleLabel(_ text: String) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: NSFont.systemFontSize)
    label.textColor = .labelColor
    label.widthAnchor.constraint(equalToConstant: SettingsLayout.textWidth).isActive = true
    return label
  }

  private func caption(_ text: String) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    label.textColor = .secondaryLabelColor
    label.preferredMaxLayoutWidth = SettingsLayout.textWidth
    return label
  }

  private func title(for intensity: ScrollIntensity) -> String {
    switch intensity {
    case .slow: "Slow"
    case .medium: "Medium"
    }
  }

  @objc private func selectPaneFromToolbar(_ sender: NSToolbarItem) {
    showPane(SettingsPane.pane(for: sender.itemIdentifier))
  }

  @objc private func selectIntensity() {
    onSelectIntensity?(ScrollIntensity(rawValue: intensityButton.selectedTag())!)
  }

  @objc private func toggleLookUp() { onToggleLookUp?() }
  @objc private func togglePrecisionScroll() { onTogglePrecisionScroll?() }
  @objc private func toggleMouseWheelDirection() { onToggleMouseWheelDirection?() }
}
