import AppKit

@MainActor final class Controller: PointerableObject, Sendable {
  private lazy var multitouchManager = IOMultitouchManager {
    self.scheduleRestart(2, reason: "Multitouch device added")
  }
  static let mouseEventHandler = MouseEventHandler()

  private var restartTimer: Timer?

  private static let fastRestart = false
  private static let wakeRestartTimeout: TimeInterval = fastRestart ? 2 : 10

  private static let immediateRestart = false

  func start() {
    log.info("Starting listeners...")

    TouchHandler.shared.registerTouchCallback()

    observeWakeNotification()
    multitouchManager.setupMultitouchListener()
    setupDisplayReconfigurationCallback()
    registerMouseCallback()
  }

  /// Schedule listeners to be restarted. If a restart is pending, discard its delay and use the most recently requested delay.
  func scheduleRestart(_ delay: TimeInterval, reason: String) {
    restartLog.info("\(reason), restarting in \(delay)")
    restartTimer?.invalidate()
    restartTimer = Timer.scheduledTimer(
      withTimeInterval: Self.immediateRestart ? 0 : delay, repeats: false
    ) { _ in
      DispatchQueue.main.async {
        self.restartListeners()
      }
    }
  }

  func restartListeners() {
    log.info("Restarting now...")
    stopUnstableListeners()
    startUnstableListeners()
    log.info("Restart success.")
  }

  private func startUnstableListeners() {
    TouchHandler.shared.registerTouchCallback()
    registerMouseCallback()
  }

  private func stopUnstableListeners() {
    TouchHandler.shared.unregisterTouchCallback()
    Self.mouseEventHandler.unregisterMouseCallback()
  }
}

fileprivate extension Controller {
  /// Callback for system wake up.
  /// Can be tested by entering `pmset sleepnow` in the Terminal
  @objc func receiveWakeNote(_ note: Notification) {
    scheduleRestart(Self.wakeRestartTimeout, reason: "System woke up")
  }

  func observeWakeNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(receiveWakeNote),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }
}

fileprivate extension Controller {
  /// TODO:? is this restart necessary? I don't see any changes when it's removed, but keep in mind I've only spent 5 minutes testing different app and system states
  static let displayReconfigurationCallback:
  CGDisplayReconfigurationCallBack = { display, flags, userData in
    if flags.containsAny(of: .setModeFlag, .addFlag, .removeFlag, .disabledFlag) {
      Controller.from(pointer: userData).scheduleRestart(2, reason: "Display reconfigured")
    }
  }

  func setupDisplayReconfigurationCallback() {
    CGDisplayRegisterReconfigurationCallback(
      Self.displayReconfigurationCallback,
      rawPointer
    )
  }
}

fileprivate extension CGDisplayChangeSummaryFlags {
  func containsAny(of flags: CGDisplayChangeSummaryFlags...) -> Bool {
    flags.contains(where: contains)
  }
}
