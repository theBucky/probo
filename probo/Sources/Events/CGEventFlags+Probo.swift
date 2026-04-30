@preconcurrency import ApplicationServices
import IOKit.hidsystem

// .maskAlternate alone leaves device-side bits set, so consumers reading raw flags still see option.
extension CGEventFlags {
  static let proboLeftOption = CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))
  static let proboRightOption = CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))
  static let proboAllOption: CGEventFlags = [.maskAlternate, .proboLeftOption, .proboRightOption]
}
