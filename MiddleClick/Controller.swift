import AppKit

@MainActor final class Controller {
  private var restartTimer: Timer?
  private var currentEventTap: CFMachPort?

  private static let fastRestart = false
  private static let wakeRestartTimeout: TimeInterval = fastRestart ? 2 : 10

  private static let immediateRestart = false

  func start() {
    log.info("Starting listeners...")

    TouchHandler.shared.registerTouchCallback()

    observeWakeNotification()
    setupMultitouchListener()
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

  /// Callback for system wake up.
  /// Can be tested by entering `pmset sleepnow` in the Terminal
  @objc private func receiveWakeNote(_ note: Notification) {
    scheduleRestart(Self.wakeRestartTimeout, reason: "System woke up")
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
    unregisterMouseCallback()
  }

  private func registerMouseCallback() {
    currentEventTap = CGEvent.tapCreate(
      tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: .from(
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp
      ), callback: Self.mouseCallback, userInfo: nil)

    if let tap = currentEventTap {
      RunLoop.current.add(tap, forMode: .common)
      CGEvent.tapEnable(tap: tap, enable: true)
    } else {
      UserDefaults.standard.set(true, forKey: "NSStatusItem Visible Item-0") // TODO use native statusItem.isVisible = true instead
      scheduleRestart(5, reason: "Couldn't create event tap (check accessibility permission)")
    }
  }

  private func unregisterMouseCallback() {
    guard let eventTap = currentEventTap else {
      log.error("Could not find the event tap to remove")
      return
    }

    // Disable the event tap first
    CGEvent.tapEnable(tap: eventTap, enable: false)

    // Remove and release the run loop source
    RunLoop.current.remove(eventTap, forMode: .common)

    // Release the event tap
    currentEventTap = nil
  }

  private func setupMultitouchListener() {
    let port = IONotificationPortCreate(kIOMasterPortDefault)

    CFRunLoopAddSource(
      RunLoop.main.getCFRunLoop(),
      IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
      .defaultMode
    )

    var handle: io_iterator_t = 0
    let err = IOServiceAddMatchingNotification(
      port,
      kIOFirstMatchNotification,
      IOServiceMatching("AppleMultitouchDevice"),
      Self.multitouchDeviceAddedCallback,
      rawPointer,
      &handle
    )

    if err != KERN_SUCCESS {
      log.error("Failed to register notification for touchpad attach: \(err), will not handle newly attached devices")
      IONotificationPortDestroy(port)
      return
    }

    Self.releaseIterator(handle)
  }

  private static func releaseIterator(_ iterator: io_iterator_t) {
    while case let ioService = IOIteratorNext(iterator), ioService != 0 {
      IOObjectRelease(ioService)
    }
  }

  private func setupDisplayReconfigurationCallback() {
    CGDisplayRegisterReconfigurationCallback(
      Self.displayReconfigurationCallback,
      rawPointer
    )
  }

  private func observeWakeNotification() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(receiveWakeNote),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )
  }

  // MARK: Callbacks

  private static let kCGMouseButtonCenter = Int64(CGMouseButton.center.rawValue)

  private static let mouseCallback: CGEventTapCallBack = {
    proxy, type, event, refcon in
    let returnedEvent = Unmanaged.passUnretained(event)
    guard !AppUtils.isIgnoredAppBundle() else { return returnedEvent }

    let state = GlobalState.shared

    if state.threeDown && (type == .leftMouseDown || type == .rightMouseDown) {
      state.wasThreeDown = true
      event.type = .otherMouseDown
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
      state.threeDown = false
      state.naturalMiddleClickLastTime = Date()
    }

    if state.wasThreeDown && (type == .leftMouseUp || type == .rightMouseUp) {
      state.wasThreeDown = false
      event.type = .otherMouseUp
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

    return returnedEvent
  }

  /// TODO? is this restart necessary? I don't see any changes when it's removed, but keep in mind I've only spent 5 minutes testing different app and system states
  private static let displayReconfigurationCallback:
  CGDisplayReconfigurationCallBack = { display, flags, userData in
    if flags.containsAny(of: .setModeFlag, .addFlag, .removeFlag, .disabledFlag) {
      Controller.from(pointer: userData).scheduleRestart(2, reason: "Display reconfigured")
    }
  }

  private static let multitouchDeviceAddedCallback: IOServiceMatchingCallback = {
    (userData, iterator) in
    releaseIterator(iterator)

    Controller.from(pointer: userData).scheduleRestart(2, reason: "Multitouch device added")
  }

  private lazy var rawPointer = Unmanaged.passUnretained(self).toOpaque()
  private static func from(pointer: UnsafeMutableRawPointer?) -> Controller {
    guard let pointer = pointer else {
      fatalError("Attempted to obtain Controller from nil pointer. This should never happen.")
    }

    return Unmanaged<Controller>.fromOpaque(pointer).takeUnretainedValue()
  }
}

extension CGDisplayChangeSummaryFlags {
  func containsAny(of flags: CGDisplayChangeSummaryFlags...) -> Bool {
    flags.contains(where: contains)
  }
}

extension CGEventMask {
  static func from(_ types: CGEventType...) -> Self {
    var mask = 0

    for type in types {
      mask |= (1 << type.rawValue)
    }

    return Self(mask)
  }
}
