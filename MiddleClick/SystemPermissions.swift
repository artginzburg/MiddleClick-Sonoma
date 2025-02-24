import CoreFoundation
@preconcurrency import ApplicationServices

class SystemPermissions {
  static func detectAccessibilityIsGranted(forcePrompt: Bool) -> Bool {
    return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): forcePrompt] as CFDictionary)
  }
}
