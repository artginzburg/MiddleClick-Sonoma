import Foundation

class AccessibilityMonitor {
  private var timer: Timer?

  private var listeners: [Listener] = []
  typealias Listener = (_ becameTrusted: Bool) -> Void

  func addListener(onChange: @escaping Listener) {
    listeners.append(onChange)
  }
  func start() {
    self.checkAccessibility()
  }

  private func startMonitoring(isTrusted: Bool) {
    timer?.invalidate()
    timer = .scheduledTimer(
      timeInterval: isTrusted ? 5 : 0.5,
      target: self,
      selector: #selector(self.checkAccessibility),
      userInfo: nil,
      repeats: true
    )
  }

  private var hasForcePrompted = false
  private var previousIsTrusted: Bool?

  @objc private func checkAccessibility() {
    let isTrusted = SystemPermissions.detectAccessibilityIsGranted(
      forcePrompt: !hasForcePrompted
    )
    if !isTrusted {
      hasForcePrompted = true
    }

    if previousIsTrusted != isTrusted {
      onTrustChange(isTrusted)
      startMonitoring(isTrusted: isTrusted)
      previousIsTrusted = isTrusted
      if previousIsTrusted == true {
        hasForcePrompted = false
      }
    }
  }

  private func onTrustChange(_ isTrusted: Bool) {
    listeners.forEach { $0(isTrusted) }
  }
}
