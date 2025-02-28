import Cocoa
import CoreGraphics
import Foundation
import IOKit
import IOKit.hid

// MARK: Globals
/// stored locally, since accessing the cache is more CPU-expensive than a local variable
@MainActor var needToClick = Config.shared.needClick
@MainActor var threeDown = false
@MainActor var wasThreeDown = false
@MainActor var naturalMiddleClickLastTime: Date?

@MainActor final class Controller: NSObject {
  private weak var restartTimer: Timer?
  private var currentEventTap: CFMachPort?
  private var currentRunLoopSource: CFRunLoopSource?

  private static let fastRestart = false
  private static let wakeRestartTimeout: TimeInterval = fastRestart ? 2 : 10

  private static let immediateRestart = false

  override init() {
    Config.shared.$needClick.onSet {
      needToClick = $0
    }
  }

  func start() {
    NSLog("Starting all listeners...")

    touchHandler.registerTouchCallback()

    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(receiveWakeNote(_:)),
      name: NSWorkspace.didWakeNotification,
      object: nil
    )

    guard let port = IONotificationPortCreate(kIOMasterPortDefault) else {
      NSLog("Failed to create IONotificationPort.")
      return
    }

    if let runLoopSource = IONotificationPortGetRunLoopSource(port)?
      .takeUnretainedValue()
    {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
    } else {
      NSLog("Failed to get run loop source from IONotificationPort.")
      IONotificationPortDestroy(port)
      return
    }

    var handle: io_iterator_t = 0
    let err = IOServiceAddMatchingNotification(
      port,
      kIOFirstMatchNotification,
      IOServiceMatching("AppleMultitouchDevice"),
      multitouchDeviceAddedCallback,
      Unmanaged.passUnretained(self).toOpaque(),
      &handle
    )

    if err != KERN_SUCCESS {
      NSLog(
        "Failed to register notification for touchpad attach: %x, will not handle newly attached devices",
        err)
      IONotificationPortDestroy(port)
      return  // this `return` was not previously here. But it's only logical to have it.
    }

    while case let ioService = IOIteratorNext(handle), ioService != 0 {
      do { IOObjectRelease(ioService) }
    }

    CGDisplayRegisterReconfigurationCallback(
      displayReconfigurationCallback,
      Unmanaged.passUnretained(self).toOpaque()
    )

    registerMouseCallback()
  }

  /// Schedule listeners to be restarted. If a restart is pending, delay it.
  func scheduleRestart(_ delay: TimeInterval) {
    restartTimer?.invalidate()
    restartTimer = Timer.scheduledTimer(
      withTimeInterval: Controller.immediateRestart ? 0 : delay, repeats: false
    ) { [weak self] _ in
      guard let self = self else { return }
      DispatchQueue.main.async {
        self.restartListeners()
      }
    }
  }

  /// Callback for system wake up.
  /// Can be tested by entering `pmset sleepnow` in the Terminal
  @objc private func receiveWakeNote(_ note: Notification) {
    NSLog("System woke up, restarting in \(Controller.wakeRestartTimeout)...")
    scheduleRestart(Controller.wakeRestartTimeout)
  }

  private func restartListeners() {
    NSLog("Restarting app functionality...")
    stopUnstableListeners()
    startUnstableListeners()
  }

  private func startUnstableListeners() {
    NSLog("Starting unstable listeners...")
    touchHandler.registerTouchCallback()
    registerMouseCallback()
  }

  private func stopUnstableListeners() {
    NSLog("Stopping unstable listeners...")
    touchHandler.unregisterTouchCallback()
    unregisterMouseCallback()
  }

  private func registerMouseCallback() {
    let eventMask = CGEventMask.from(.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp)
    currentEventTap = CGEvent.tapCreate(
      tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
      eventsOfInterest: eventMask, callback: mouseCallback, userInfo: nil)

    if let tap = currentEventTap {
      currentRunLoopSource = CFMachPortCreateRunLoopSource(
        kCFAllocatorDefault, tap, 0)
      CFRunLoopAddSource(
        CFRunLoopGetCurrent(), currentRunLoopSource, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
    } else {
      NSLog("Couldn't create event tap! Check accessibility permissions.")
      UserDefaults.standard.set(true, forKey: "NSStatusItem Visible Item-0")
      scheduleRestart(5)
    }
  }

  private func unregisterMouseCallback() {
    // Disable the event tap first
    if let eventTap = currentEventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }

    // Remove and release the run loop source
    if let runLoopSource = currentRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      currentRunLoopSource = nil
    }

    // Release the event tap
    currentEventTap = nil
  }
}

@MainActor private let mouseCallback: CGEventTapCallBack = {
  proxy, type, event, refcon in
  if isIgnoredAppBundle() { return Unmanaged.passUnretained(event) }

    if threeDown && (type == .leftMouseDown || type == .rightMouseDown) {
      wasThreeDown = true
      event.type = .otherMouseDown
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
      threeDown = false
      naturalMiddleClickLastTime = Date()
    }

    if wasThreeDown && (type == .leftMouseUp || type == .rightMouseUp) {
      wasThreeDown = false
      event.type = .otherMouseUp
      event.setIntegerValueField(.mouseEventButtonNumber, value: kCGMouseButtonCenter)
    }

  return Unmanaged.passUnretained(event)
}

@MainActor var ignoredAppBundlesCache = Config.shared.ignoredAppBundles

/// Caveat: Depends on getFocusedApp(), but the cursor may actually be above a window that is not currently focused, in which case a middle-click will pass through to an "Ignored" application.
@MainActor func isIgnoredAppBundle() -> Bool {
  guard let bundleId = getFocusedApp()?.bundleIdentifier else { return false }
  return ignoredAppBundlesCache.contains(bundleId)
}

/// TODO? is this restart necessary? I don't see any changes when it's removed, but keep in mind I've only spent 5 minutes testing different app and system states
@MainActor private let displayReconfigurationCallback:
  CGDisplayReconfigurationCallBack = { display, flags, userData in
    if flags.contains(.setModeFlag) || flags.contains(.addFlag)
      || flags.contains(.removeFlag) || flags.contains(.disabledFlag)
    {
      print("Display reconfigured, restarting...")
      let controller = Unmanaged<Controller>.fromOpaque(userData!)
        .takeUnretainedValue()
      controller.scheduleRestart(2)
    }
  }

func getFocusedApp() -> NSRunningApplication? {
  return NSWorkspace.shared.frontmostApplication
}

@MainActor private let multitouchDeviceAddedCallback: IOServiceMatchingCallback = {
  (userData, iterator) in
  while case let ioService = IOIteratorNext(iterator), ioService != 0 {
    do { IOObjectRelease(ioService) }
  }

  let controller = Unmanaged<Controller>.fromOpaque(userData!)
    .takeUnretainedValue()
  NSLog("Multitouch device added, restarting...")
  controller.scheduleRestart(2)
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
