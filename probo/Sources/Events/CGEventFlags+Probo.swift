@preconcurrency import ApplicationServices

// .maskAlternate alone leaves device-side bits set, so consumers reading raw flags still see option.
extension CGEventFlags {
  static let proboLeftOption = CGEventFlags(rawValue: 0x20)
  static let proboRightOption = CGEventFlags(rawValue: 0x40)
  static let proboAllOption: CGEventFlags = [.maskAlternate, .proboLeftOption, .proboRightOption]
}
