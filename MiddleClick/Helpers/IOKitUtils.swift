import IOKit

enum IOKitUtils {
  static func releaseIterator(_ iterator: io_iterator_t) {
    while case let ioService = IOIteratorNext(iterator), ioService != 0 {
      IOObjectRelease(ioService)
    }
  }
}
