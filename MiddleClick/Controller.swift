import Cocoa
import CoreGraphics
import Foundation
import IOKit
import IOKit.hid

// Globals
@MainActor public var needToClick = MiddleClickConfig.needClickDefault
@MainActor public var threeDown = false
@MainActor public var wasThreeDown = false
@MainActor public var maybeMiddleClick = false
@MainActor public var touchStartTime: Date?
@MainActor var naturalMiddleClickLastTime: Date?
@MainActor public var middleClickX: Float = 0.0
@MainActor public var middleClickY: Float = 0.0
@MainActor public var middleClickX2: Float = 0.0
@MainActor public var middleClickY2: Float = 0.0
@MainActor public var fingersQua = UserDefaults.standard.integer(
  forKey: MiddleClickConfig.fingersNumKey)
@MainActor public let maxDistanceDelta = UserDefaults.standard.float(
  forKey: MiddleClickConfig.maxDistanceDeltaKey)
@MainActor public let maxTimeDelta =
UserDefaults.standard
  .double(forKey: MiddleClickConfig.maxTimeDeltaMsKey) / 1000.0
@MainActor public var allowMoreFingers = UserDefaults.standard.bool(
  forKey: MiddleClickConfig.allowMoreFingersKey)

@MainActor class Controller: NSObject {
  weak var restartTimer: Timer?
  var currentEventTap: CFMachPort?
  var currentRunLoopSource: CFRunLoopSource?

  static let fastRestart = false
  static let wakeRestartTimeout: TimeInterval = fastRestart ? 2 : 10

  static let immediateRestart = false

  var currentDeviceList: [MTDevice] = []

  func start() {
    NSLog("Starting all listeners...")

    needToClick =
      UserDefaults.standard.value(forKey: "needClick") as? Bool
      ?? getIsSystemTapToClickDisabled()

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
  @objc func receiveWakeNote(_ note: Notification) {
    NSLog("System woke up, restarting in \(Controller.wakeRestartTimeout)...")
    scheduleRestart(Controller.wakeRestartTimeout)
  }

  func getClickMode() -> Bool {
    return needToClick
  }

  func setMode(_ click: Bool) {
    UserDefaults.standard.set(click, forKey: MiddleClickConfig.needClickKey)
    needToClick = click
  }

  func resetClickMode() {
    UserDefaults.standard.removeObject(forKey: MiddleClickConfig.needClickKey)
    needToClick = getIsSystemTapToClickDisabled()
  }

  func restartListeners() {
    NSLog("Restarting app functionality...")
    stopUnstableListeners()
    startUnstableListeners()
  }

  func startUnstableListeners() {
    NSLog("Starting unstable listeners...")
    registerTouchCallback()
    registerMouseCallback()
  }

  func stopUnstableListeners() {
    NSLog("Stopping unstable listeners...")
    unregisterTouchCallback()
    unregisterMouseCallback()
  }

  func registerMouseCallback() {
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

  func registerTouchCallback() {
    currentDeviceList =
      (MTDeviceCreateList()?.takeUnretainedValue() as? [MTDevice]) ?? []

    currentDeviceList.forEach { registerMTDeviceCallback($0, touchCallback) }
  }

  func unregisterTouchCallback() {
    currentDeviceList.forEach { unregisterMTDeviceCallback($0, touchCallback) }
    currentDeviceList.removeAll()
  }

  func getIsSystemTapToClickDisabled() -> Bool {
    let output = runCommand(
      "defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking"
    )
    return output == "0\n"
  }

  func runCommand(_ command: String) -> String {
    let pipe = Pipe()
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", command]
    task.standardOutput = pipe

    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }

}

@MainActor let mouseCallback: CGEventTapCallBack = {
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

@MainActor func shouldPreventEmulation() -> Bool {
  if let naturalLastTime = naturalMiddleClickLastTime {
    let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow;
    if elapsedTimeSinceNatural <= maxTimeDelta * 0.75 {
      return true
    }
  }
  return false
}

/// Caveat: Depends on getFocusedApp(), but the cursor may actually be above a window that is not currently focused, in which case a middle-click will pass through to an "Ignored" application.
func isIgnoredAppBundle() -> Bool {
  let ignoredAppBundles = UserDefaults.standard.stringArray(
    forKey: MiddleClickConfig.ignoredAppBundlesKey
  ) ?? MiddleClickConfig.ignoredAppBundlesDefault

  guard let bundleId = getFocusedApp()?.bundleIdentifier else { return false }

  return ignoredAppBundles.contains(bundleId)
}

@MainActor func touchCallback(
  device: Int32, data: UnsafeMutablePointer<Finger>?, nFingers: Int32,
  timestamp: Double, frame: Int32
) -> Int32 {
  if isIgnoredAppBundle() { return 0 }

    threeDown =
      allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua

  let tapToClickEnabled = !needToClick;
  if (!tapToClickEnabled) { return 0; }

  if nFingers == 0 {
    if let startTime = touchStartTime {
      let elapsedTime = -startTime.timeIntervalSinceNow
      touchStartTime = nil

      if middleClickX + middleClickY > 0 && elapsedTime <= maxTimeDelta {
        let delta =
          abs(middleClickX - middleClickX2)
          + abs(middleClickY - middleClickY2)
        if delta < maxDistanceDelta {
          if !shouldPreventEmulation() {
            emulateMiddleClick()
          }
        }
      }
    }
  } else if nFingers > 0 && touchStartTime == nil {
    touchStartTime = Date()
    maybeMiddleClick = true
    middleClickX = 0.0
    middleClickY = 0.0
  } else if maybeMiddleClick {
    let elapsedTime = -(touchStartTime?.timeIntervalSinceNow ?? 0)
    if elapsedTime > maxTimeDelta {
      maybeMiddleClick = false
    }
  }

  if !allowMoreFingers && nFingers > fingersQua {
    maybeMiddleClick = false
    middleClickX = 0.0
    middleClickY = 0.0
  }

  if allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua {
    if maybeMiddleClick {
      //      middleClickX = 0.0 // TODO check if setting to 0 is necessary here
      //      middleClickY = 0.0
      for i in 0..<fingersQua {
        if let fingerData = data?.advanced(by: Int(i)).pointee {
          let pos = fingerData.normalized.pos
          middleClickX += pos.x
          middleClickY += pos.y
        }
      }
      middleClickX2 = middleClickX
      middleClickY2 = middleClickY
      maybeMiddleClick = false
    } else {
      middleClickX2 = 0.0
      middleClickY2 = 0.0
      for i in 0..<fingersQua {
        if let fingerData = data?.advanced(by: Int(i)).pointee {
          let pos = fingerData.normalized.pos
          middleClickX2 += pos.x
          middleClickY2 += pos.y
        }
      }
    }
  }

  return 0
}

/// TODO? is this restart necessary? I don't see any changes when it's removed, but keep in mind I've only spent 5 minutes testing different app and system states
@MainActor public let displayReconfigurationCallback:
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

public func emulateMiddleClick() {
  // get the current pointer location
  let location = CGEvent(source: nil)?.location ?? .zero
  let buttonType: CGMouseButton = .center

  postMouseEvent(type: .otherMouseDown, button: buttonType, location: location)
  postMouseEvent(type: .otherMouseUp, button: buttonType, location: location)
}

func getFocusedApp() -> NSRunningApplication? {
  return NSWorkspace.shared.frontmostApplication
}

public func postMouseEvent(
  type: CGEventType, button: CGMouseButton, location: CGPoint
) {
  if let event = CGEvent(
    mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
    mouseButton: button)
  {
    event.post(tap: .cghidEventTap)
  }
}

@MainActor let multitouchDeviceAddedCallback: IOServiceMatchingCallback = {
  (userData, iterator) in
  while case let ioService = IOIteratorNext(iterator), ioService != 0 {
    do { IOObjectRelease(ioService) }
  }

  let controller = Unmanaged<Controller>.fromOpaque(userData!)
    .takeUnretainedValue()
  NSLog("Multitouch device added, restarting...")
  controller.scheduleRestart(2)
}

func registerMTDeviceCallback(
  _ device: MTDevice, _ callback: @escaping MTContactCallbackFunction
) {
  MTRegisterContactFrameCallback(device, callback)
  MTDeviceStart(device, 0)
}

func unregisterMTDeviceCallback(
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
