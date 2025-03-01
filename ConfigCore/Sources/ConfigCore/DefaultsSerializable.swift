public protocol DefaultsSerializable {
  // swiftlint:disable:next type_name
  typealias T = Bridge.T
  associatedtype Bridge: DefaultsBridge
  //  associatedtype ArrayBridge: DefaultsBridge

  static var _defaults: Bridge { get }
  //  static var _defaultsArray: ArrayBridge { get }
}

/// A marker protocol for simple types, such as String, Bool, Int
protocol DefaultsSimpleSerializable: DefaultsSerializable {}
extension DefaultsSimpleSerializable {
  public static var _defaults: DefaultsGeneralBridge { DefaultsGeneralBridge() }
}

extension Bool: DefaultsSimpleSerializable {}
extension String: DefaultsSimpleSerializable {}
extension Int: DefaultsSimpleSerializable {}
extension Double: DefaultsSimpleSerializable {}
extension Float: DefaultsSimpleSerializable {}
extension [String]: DefaultsSimpleSerializable, DefaultsSerializable where Element == String {}

extension Set<String>: DefaultsSerializable {
  public static var _defaults: DefaultsSetStringBridge { DefaultsSetStringBridge() }
}
