import IOKit
import Foundation.NSRunLoop

final class IOMultitouchManager: PointerableObject {
  let deviceAddedCallback: () -> Void
  init(deviceAddedCallback: @escaping () -> Void) {
    self.deviceAddedCallback = deviceAddedCallback
  }

  func setupMultitouchListener() {
    let port = IONotificationPortCreate(kIOMasterPortDefault)

    CFRunLoopAddSource(
      RunLoop.main.getCFRunLoop(), // TODO: ? use .current
      IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
      .defaultMode
    )

    var handle: io_iterator_t = 0
    let err = IOServiceAddMatchingNotification(
      port,
      kIOFirstMatchNotification,
      IOServiceMatching("AppleMultitouchDevice"),
      {
        (userData, iterator) in
        IOKitUtils.releaseIterator(iterator)
        IOMultitouchManager.from(pointer: userData).deviceAddedCallback()
      },
      rawPointer,
      &handle
    )

    if err != KERN_SUCCESS {
      log.error("Failed to register notification for touchpad attach: \(err), will not handle newly attached devices")
      IONotificationPortDestroy(port)
      return
    }

    IOKitUtils.releaseIterator(handle)
  }
}
