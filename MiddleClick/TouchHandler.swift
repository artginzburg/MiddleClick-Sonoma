import Foundation
import CoreGraphics
import MoreTouchCore
import MultitouchSupport

@MainActor class TouchHandler {
  static let shared = TouchHandler()
  private init() {
    Config.shared.$tapToClick.onSet {
      self.tapToClick = $0
    }
  }

  /// stored locally, since accessing the cache is more CPU-expensive than a local variable
  var tapToClick = Config.shared.tapToClick

  private static let fingersQua = Config.shared.minimumFingers
  private static let allowMoreFingers = Config.shared.allowMoreFingers
  private static let maxDistanceDelta = Config.shared.maxDistanceDelta
  private static let maxTimeDelta = Config.shared.maxTimeDelta

  private var maybeMiddleClick = false
  private var touchStartTime: Date?
  private var middleClickX: Float = 0.0
  private var middleClickY: Float = 0.0
  private var middleClickX2: Float = 0.0
  private var middleClickY2: Float = 0.0

  private let touchCallback: MTFrameCallbackFunction = {
    device, data, nFingers, timestamp, frame in
    guard !AppUtils.isIgnoredAppBundle() else { return }

    let state = GlobalState.shared

    state.threeDown =
    allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua

    let handler = TouchHandler.shared

    guard handler.tapToClick else { return }

    guard nFingers != 0 else {
      handler.handleTouchEnd()
      return
    }

    let isTouchStart = nFingers > 0 && handler.touchStartTime == nil
    if isTouchStart {
      handler.touchStartTime = Date()
      handler.maybeMiddleClick = true
      handler.middleClickX = 0.0
      handler.middleClickY = 0.0
    } else if handler.maybeMiddleClick, let touchStartTime = handler.touchStartTime {
      // Timeout check for middle click
      let elapsedTime = -touchStartTime.timeIntervalSinceNow
      if elapsedTime > maxTimeDelta {
        handler.maybeMiddleClick = false
      }
    }

    guard !(nFingers < fingersQua) else { return }

    if !allowMoreFingers && nFingers > fingersQua {
      handler.resetMiddleClick()
    }

    let isCurrentFingersQuaAllowed = allowMoreFingers ? nFingers >= fingersQua : nFingers == fingersQua
    guard isCurrentFingersQuaAllowed else { return }

    handler.processTouches(data: data, nFingers: nFingers)

    return
  }

  private func processTouches(data: UnsafePointer<MTTouch>?, nFingers: Int32) {
    guard let data = data else { return }

    if maybeMiddleClick {
      middleClickX = 0.0
      middleClickY = 0.0
    } else {
      middleClickX2 = 0.0
      middleClickY2 = 0.0
    }

//    TODO: Wait, what? Why is this iterating by fingersQua instead of nFingers, given that e.g. "allowMoreFingers" exists?
    for i in 0..<Self.fingersQua {
      let pos = data.advanced(by: i).pointee.normalizedVector.position
      if maybeMiddleClick {
        middleClickX += pos.x
        middleClickY += pos.y
      } else {
        middleClickX2 += pos.x
        middleClickY2 += pos.y
      }
    }

    if maybeMiddleClick {
      middleClickX2 = middleClickX
      middleClickY2 = middleClickY
      maybeMiddleClick = false
    }
  }

  private func resetMiddleClick() {
    maybeMiddleClick = false
    middleClickX = 0.0
    middleClickY = 0.0
  }

  fileprivate func handleTouchEnd() {
    guard let startTime = touchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    touchStartTime = nil

    guard middleClickX + middleClickY > 0 && elapsedTime <= Self.maxTimeDelta else {
      return
    }

    let delta = abs(middleClickX - middleClickX2) + abs(middleClickY - middleClickY2)
    if delta < Self.maxDistanceDelta && !shouldPreventEmulation() {
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
    guard let naturalLastTime = GlobalState.shared.naturalMiddleClickLastTime else { return false }

    let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow
    return elapsedTimeSinceNatural <= Self.maxTimeDelta * 0.75 // fine-tuned multiplier
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

    currentDeviceList.forEach { $0.registerAndStart(touchCallback) }
  }
  func unregisterTouchCallback() {
    currentDeviceList.forEach { $0.unregisterAndStop(touchCallback) }
    currentDeviceList.removeAll()
  }
}
