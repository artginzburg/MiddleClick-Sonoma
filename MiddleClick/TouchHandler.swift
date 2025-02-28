import Foundation
import CoreGraphics

@MainActor let touchHandler = TouchHandler()

@MainActor private let fingersQua = Config.shared.minimumFingers
@MainActor private let allowMoreFingers = Config.shared.allowMoreFingers
@MainActor private let maxDistanceDelta = Config.shared.maxDistanceDelta
@MainActor private let maxTimeDelta = Config.shared.maxTimeDelta

@MainActor private var maybeMiddleClick = false
@MainActor private var touchStartTime: Date?
@MainActor private var middleClickX: Float = 0.0
@MainActor private var middleClickY: Float = 0.0
@MainActor private var middleClickX2: Float = 0.0
@MainActor private var middleClickY2: Float = 0.0

@MainActor private let touchCallback: MTContactCallbackFunction = {
  device, data, nFingers, timestamp, frame in
  guard !isIgnoredAppBundle() else { return 0 }

  threeDown =
  allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua

  guard !needToClick else { return 0 }

  guard nFingers != 0 else {
    touchHandler.handleTouchEnd()
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

  guard !(nFingers < fingersQua) else { return 0 }

  if !allowMoreFingers && nFingers > fingersQua {
    maybeMiddleClick = false
    middleClickX = 0.0
    middleClickY = 0.0
  }

  let isCurrentFingersQuaAllowed = allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua
  guard isCurrentFingersQuaAllowed else { return 0 }

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

@MainActor class TouchHandler {
  fileprivate func handleTouchEnd() {
    guard let startTime = touchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    touchStartTime = nil

    guard middleClickX + middleClickY > 0 && elapsedTime <= maxTimeDelta else {
      return
    }

    let delta = abs(middleClickX - middleClickX2) + abs(middleClickY - middleClickY2)
    if delta < maxDistanceDelta && !shouldPreventEmulation() {
      Self.emulateMiddleClick()
    }
  }

  private static func emulateMiddleClick() {
    // get the current pointer location
    let location = CGEvent(source: nil)?.location ?? .zero
    let buttonType: CGMouseButton = .center

    postMouseEvent(type: .otherMouseDown, button: buttonType, location: location)
    postMouseEvent(type: .otherMouseUp, button: buttonType, location: location)
  }

  private func shouldPreventEmulation() -> Bool {
    guard let naturalLastTime = naturalMiddleClickLastTime else { return false }

    let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow
    return elapsedTimeSinceNatural <= maxTimeDelta * 0.75 // fine-tuned multiplier
  }

  private static func postMouseEvent(
    type: CGEventType, button: CGMouseButton, location: CGPoint
  ) {
    if let event = CGEvent(
      mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
      mouseButton: button)
    {
      event.post(tap: .cghidEventTap)
    }
  }

  private var currentDeviceList: [MTDevice] = []
  func registerTouchCallback() {
    currentDeviceList =
    (MTDeviceCreateList()?.takeUnretainedValue() as? [MTDevice]) ?? []

    currentDeviceList.forEach { registerMTDeviceCallback($0, touchCallback) }
  }
  func unregisterTouchCallback() {
    currentDeviceList.forEach { unregisterMTDeviceCallback($0, touchCallback) }
    currentDeviceList.removeAll()
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
}
