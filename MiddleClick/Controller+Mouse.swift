import CoreGraphics
import Foundation

extension Controller {
  private static let state = GlobalState.shared
  private static let kCGMouseButtonCenter = Int64(CGMouseButton.center.rawValue)

  func registerMouseCallback() {
    if !Self.mouseEventHandler.registerMouseCallback(callback: Self.mouseCallback) {
      log.info("Couldn't create event tap (check accessibility permission)")
    }
  }

  private static let mouseCallback: CGEventTapCallBack = {
    proxy, type, event, refcon in
    let returnedEvent = Unmanaged.passUnretained(event)
    guard !AppUtils.isIgnoredAppBundle() else { return returnedEvent }
    
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
}

class MouseEventHandler {
  private var currentEventTap: CFMachPort?

  func registerMouseCallback(callback: CGEventTapCallBack) -> Bool {
    currentEventTap = CGEvent.tapCreate(
      tap: .cghidEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: .from(
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp
      ),
      callback: callback,
      userInfo: nil
    )

    if let tap = currentEventTap {
      RunLoop.current.add(tap, forMode: .common)
      CGEvent.tapEnable(tap: tap, enable: true)
    } else {
      return false
    }

    return true
  }

  func unregisterMouseCallback() {
    guard let eventTap = currentEventTap else {
      log.info("Could not find the event tap to remove")
      return
    }

    // Disable the event tap first
    CGEvent.tapEnable(tap: eventTap, enable: false)

    // Remove and release the run loop source
    RunLoop.current.remove(eventTap, forMode: .common)

    // Release the event tap
    currentEventTap = nil
  }
}

fileprivate extension CGEventMask {
  static func from(_ types: CGEventType...) -> Self {
    var mask = 0

    for type in types {
      mask |= (1 << type.rawValue)
    }

    return Self(mask)
  }
}
