import Cocoa
import CoreGraphics
import Foundation
import IOKit
import IOKit.hid

// MARK: Globals
/// stored locally, since accessing the cache is more CPU-expensive than a local variable
@MainActor private var needToClick = Config.shared.needClick
@MainActor private var threeDown = false
@MainActor private var wasThreeDown = false
@MainActor private var maybeMiddleClick = false
@MainActor private var touchStartTime: Date?
@MainActor private var naturalMiddleClickLastTime: Date?
@MainActor private var middleClickX: Float = 0.0
@MainActor private var middleClickY: Float = 0.0
@MainActor private var middleClickX2: Float = 0.0
@MainActor private var middleClickY2: Float = 0.0

@MainActor private let fingersQua = Config.shared.minimumFingers
@MainActor private let maxDistanceDelta = Config.shared.maxDistanceDelta
@MainActor private let maxTimeDelta = Config.shared.maxTimeDelta
@MainActor private let allowMoreFingers = Config.shared.allowMoreFingers

@MainActor final class Controller: NSObject {
  private weak var restartTimer: Timer?
  private var currentEventTap: CFMachPort?
  private var currentRunLoopSource: CFRunLoopSource?

  private static let fastRestart = false
  private static let wakeRestartTimeout: TimeInterval = fastRestart ? 2 : 10

  private static let immediateRestart = false

  private var currentDeviceList: [MTDevice] = []

  override init() {
    Config.shared.$needClick.onSet {
      needToClick = $0
    }
  }

  func start() {
    NSLog("Starting all listeners...")

    registerTouchCallback()

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
    registerTouchCallback()
    registerMouseCallback()
  }

  private func stopUnstableListeners() {
    NSLog("Stopping unstable listeners...")
    unregisterTouchCallback()
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

  private func registerTouchCallback() {
    currentDeviceList =
      (MTDeviceCreateList()?.takeUnretainedValue() as? [MTDevice]) ?? []

    currentDeviceList.forEach { registerMTDeviceCallback($0, touchCallback) }
  }

  private func unregisterTouchCallback() {
    currentDeviceList.forEach { unregisterMTDeviceCallback($0, touchCallback) }
    currentDeviceList.removeAll()
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

@MainActor private func shouldPreventEmulation() -> Bool {
  guard let naturalLastTime = naturalMiddleClickLastTime else { return false }

  let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow
  return elapsedTimeSinceNatural <= maxTimeDelta * 0.75 // fine-tuned multiplier
}

@MainActor var ignoredAppBundlesCache = Config.shared.ignoredAppBundles

/// Caveat: Depends on getFocusedApp(), but the cursor may actually be above a window that is not currently focused, in which case a middle-click will pass through to an "Ignored" application.
@MainActor func isIgnoredAppBundle() -> Bool {
  guard let bundleId = getFocusedApp()?.bundleIdentifier else { return false }
  return ignoredAppBundlesCache.contains(bundleId)
}

@MainActor private func handleTouchEnd() {
  guard let startTime = touchStartTime else { return }

  let elapsedTime = -startTime.timeIntervalSinceNow
  touchStartTime = nil

  guard middleClickX + middleClickY > 0 && elapsedTime <= maxTimeDelta else {
    return
  }

  let delta = abs(middleClickX - middleClickX2) + abs(middleClickY - middleClickY2)
  if delta < maxDistanceDelta && !shouldPreventEmulation() {
    emulateMiddleClick()
  }
}

@MainActor private let touchCallback: MTContactCallbackFunction = {
  device, data, nFingers, timestamp, frame in
  if isIgnoredAppBundle() { return 0 }

    threeDown =
      allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua

  if needToClick { return 0 }

  if nFingers == 0 {
    handleTouchEnd()
    return 0
  }

  let isTouchStart = nFingers > 0 && touchStartTime == nil
  if isTouchStart {
    touchStartTime = Date()
    maybeMiddleClick = true
    middleClickX = 0.0
    middleClickY = 0.0
  } else if maybeMiddleClick, let touchStartTime = touchStartTime {
    // Timeout check for middle click
    let elapsedTime = -touchStartTime.timeIntervalSinceNow
    if elapsedTime > maxTimeDelta {
      maybeMiddleClick = false
    }
  }

  if nFingers < fingersQua { return 0 }

  if !allowMoreFingers && nFingers > fingersQua {
    maybeMiddleClick = false
    middleClickX = 0.0
    middleClickY = 0.0
  }

  let isCurrentFingersQuaAllowed = allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua
  if !isCurrentFingersQuaAllowed { return 0 }

  if maybeMiddleClick {
    middleClickX = 0.0
    middleClickY = 0.0
  } else {
    middleClickX2 = 0.0
    middleClickY2 = 0.0
  }

  for i in 0..<fingersQua {
    if let fingerData = data?.advanced(by: i).pointee {
      let pos = fingerData.normalized.pos
      if maybeMiddleClick {
        middleClickX += pos.x
        middleClickY += pos.y
      } else {
        middleClickX2 += pos.x
        middleClickY2 += pos.y
      }
    }
  }

  if maybeMiddleClick {
    middleClickX2 = middleClickX
    middleClickY2 = middleClickY
    maybeMiddleClick = false
  }

  return 0
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

private func emulateMiddleClick() {
  // get the current pointer location
  let location = CGEvent(source: nil)?.location ?? .zero
  let buttonType: CGMouseButton = .center

  postMouseEvent(type: .otherMouseDown, button: buttonType, location: location)
  postMouseEvent(type: .otherMouseUp, button: buttonType, location: location)
}

private func postMouseEvent(
  type: CGEventType, button: CGMouseButton, location: CGPoint
) {
  if let event = CGEvent(
    mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
    mouseButton: button)
  {
    event.post(tap: .cghidEventTap)
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

private func registerMTDeviceCallback(
  _ device: MTDevice, _ callback: @escaping MTContactCallbackFunction
) {
  MTRegisterContactFrameCallback(device, callback)
  MTDeviceStart(device, 0)
}

private func unregisterMTDeviceCallback(
  _ device: MTDevice, _ callback: @escaping MTContactCallbackFunction
) {
  MTUnregisterContactFrameCallback(device, callback)
  MTDeviceStop(device)
  MTDeviceRelease(device)
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
