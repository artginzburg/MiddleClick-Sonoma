/// The title explains itself.
///
/// Refer to ``rawPointer`` for usage details
protocol Pointerable: AnyObject {}
extension Pointerable {
  static func from(pointer: UnsafeMutableRawPointer?) -> Self {
    guard let pointer = pointer else {
      fatalError("Attempted to obtain Controller from nil pointer. This should never happen.")
    }

    return Unmanaged<Self>.fromOpaque(pointer).takeUnretainedValue()
  }

  /// Gets the instance as an opaque pointer.
  ///
  /// Remember to add this line to `YourClass: Pointerable`, to avoid multiple initializations (non-critical)
  /// ```swift
  /// lazy var rawPointer = rawPointer
  /// ```
  var rawPointer: UnsafeMutableRawPointer {
    return Unmanaged.passUnretained(self).toOpaque()
  }
}
class PointerableObject: Pointerable {
  lazy var rawPointer = rawPointer
}
