import MoreTouchCore
import MultitouchSupport

@MainActor class TouchHandler {
  static let shared = TouchHandler()
  private static let config = Config.shared
  private init() {
    Self.config.$tapToClick.onSet {
      self.tapToClick = $0
    }
  }

  /// stored locally, since accessing the cache is more CPU-expensive than a local variable
  private var tapToClick = config.tapToClick

  private static let fingersQua = config.minimumFingers
  private static let allowMoreFingers = config.allowMoreFingers
  private static let maxDistanceDelta = config.maxDistanceDelta
  private static let maxTimeDelta = config.maxTimeDelta

  private var maybeMiddleClick = false
  private var touchStartTime: Date?
  private var middleClickPos1: SIMD2<Float> = .zero
  private var middleClickPos2: SIMD2<Float> = .zero

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
      handler.middleClickPos1 = .zero
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
      middleClickPos1 = .zero
    } else {
      middleClickPos2 = .zero
    }

//    TODO: Wait, what? Why is this iterating by fingersQua instead of nFingers, given that e.g. "allowMoreFingers" exists?
    for touch in UnsafeBufferPointer(start: data, count: Self.fingersQua) {
      let pos = SIMD2(touch.normalizedVector.position)
      if maybeMiddleClick {
        middleClickPos1 += pos
      } else {
        middleClickPos2 += pos
      }
    }

    if maybeMiddleClick {
      middleClickPos2 = middleClickPos1
      maybeMiddleClick = false
    }
  }

  private func resetMiddleClick() {
    maybeMiddleClick = false
    middleClickPos1 = .zero
  }

  private func handleTouchEnd() {
    guard let startTime = touchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    touchStartTime = nil

    guard middleClickPos1.isNonZero && elapsedTime <= Self.maxTimeDelta else { return }

    let delta = middleClickPos1.delta(to: middleClickPos2)
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
    CGEvent(
      mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
      mouseButton: button
    )?.post(tap: .cghidEventTap)
  }

  private var currentDeviceList: [MTDevice] = []
  func registerTouchCallback() {
    currentDeviceList = MTDevice.createList()
    currentDeviceList.forEach { $0.registerAndStart(touchCallback) }
  }
  func unregisterTouchCallback() {
    currentDeviceList.forEach { $0.unregisterAndStop(touchCallback) }
    currentDeviceList.removeAll()
  }
}

extension SIMD2 where Scalar == Float {
  init(_ point: MTPoint) { self.init(point.x, point.y) }
}
extension SIMD2 where Scalar: FloatingPoint {
  func delta(to other: SIMD2) -> Scalar {
    return abs(x - other.x) + abs(y - other.y)
  }

  var isNonZero: Bool { x != 0 || y != 0 }
}
