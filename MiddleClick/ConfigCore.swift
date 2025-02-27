import Foundation

// Huge thanks to https://github.com/sunshinejr/SwiftyUserDefaults .
// I found it too late, but some parts of it, like the DefaultsBridge, are just gold.

public protocol DefaultsBridge {
  associatedtype T
  func get(key: String, userDefaults: UserDefaults) -> T
  func save(key: String, value: T, userDefaults: UserDefaults)
}

public struct DefaultsGeneralBridge: DefaultsBridge {
  public typealias T = Any
  public func get(key: String, userDefaults: UserDefaults) -> T {
    return userDefaults.value(forKey: key) as T
  }
  public func save(key: String, value: T, userDefaults: UserDefaults) {
    userDefaults.set(value, forKey: key)
  }
}
public struct DefaultsSetStringBridge: DefaultsBridge {
  public typealias T = Set<String>
  public func get(key: String, userDefaults: UserDefaults) -> T {
    return Set(userDefaults.stringArray(forKey: key) ?? [])
  }
  public func save(key: String, value: T, userDefaults: UserDefaults) {
    userDefaults.set(Array(value), forKey: key)
  }
}


public protocol DefaultsSerializable {
  // swiftlint:disable:next type_name
  typealias T = Bridge.T
  associatedtype Bridge: DefaultsBridge
//  associatedtype ArrayBridge: DefaultsBridge

  static var _defaults: Bridge { get }
//  static var _defaultsArray: ArrayBridge { get }
}

/// A marker protocol for simple types, such as String, Bool, Int
public protocol DefaultsSimpleSerializable: DefaultsSerializable {}
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
  public static var _defaults: DefaultsSetStringBridge { return DefaultsSetStringBridge() }
}


internal enum UserDefaultGetter<T: DefaultsSerializable> {
  case standard

  var getFunc: (_ forKey: String) -> (any DefaultsSerializable)? {
    switch T.self {
    case is Bool.Type:
      return UserDefaults.standard.bool
    case is String.Type:
      return UserDefaults.standard.string
    case is Int.Type:
      return UserDefaults.standard.integer
    case is Double.Type:
      return UserDefaults.standard.double
    case is Float.Type:
      return UserDefaults.standard.float
    case is [String].Type:
      return UserDefaults.standard.stringArray
    default:
      return {
        T._defaults.get(key: $0, userDefaults: UserDefaults.standard) as? any DefaultsSerializable
      }
    }
  }
}

@MainActor class DefaultsInitStorage {
  private static let shared = DefaultsInitStorage()
  private init() {}

  private var store: [String : Any] = [:]
  static func preRegister(_ key: String, _ defaultValue: Any) {
    if let defaultValueAsSet = defaultValue as? Set<String> {
      shared.store[key] = Array(defaultValueAsSet)
      return
    }

    shared.store[key] = defaultValue
  }

  static func register() {
    guard shared.store.count > 0 else { return }

    UserDefaults.standard.register(defaults: shared.store)
  }
}

/**
 Extend this class to define your Config

 ```swift
 final class Config: UserDefaultsInitializer { ... }
 ```
 # Usage
 - Define your keys (without `static`):
   ```swift
   @UserDefault("fingers") // <- key
   var minimumFingers = 3 // <- default value
   ```
 - Use them via `.shared`:
   ```swift
   let fingersQuantity = Config.shared.minimumFingers
   ```
 - More options you can discover, using auto-completions on ``UserDefault``:
    - caching
    - using a function as the default value (waits until the property is first accessed)

 ## Global options
 ``GlobalDefaultsOptions`` can be modified. For convenience (and proper lazy access), use the init function of your Config, like so:
 ```swift
 required init() {
   Self.options.cacheAll = true
 }
 ```
*/
@MainActor class ConfigCore: Singleton {
  static let options = GlobalDefaultsOptions.self

  required init() {
    DefaultsInitStorage.register()

// //    TODO figure out a way to use the .label as the key of the UserDefault, in order to skip having to specify a literal key. Maybe we'll have to sacrifice UserDefaults.standard.register(), or at least defer it.
// //    We can store the labels wherever we want, e.g.:
// //       use random string generation as keys for calling UserDefaults.standard.register()
// //        Then, when wrappedValue get or set is called, we will know the actual key, so we'll be able to remap the random keys to the true keys.

//    let mirror = Mirror(reflecting: self)
//    for child in mirror.children {
//      guard let rawLabel = child.label else { continue }
//      if let safeUserDefault = child.value as? AnyExperimentalUserDefault {
//        print("I am the actual key label, and I've also got access to the UserDefault object -", rawLabel)
//      }
//    }
  }
}

protocol OptionSetInt: OptionSet {}
extension OptionSetInt where Self.RawValue == Int8 {
  init(_ bit: Int8) {
    self.init(rawValue: 1 << bit)
  }
}

struct UserDefaultOptions: OptionSetInt {
  internal let rawValue: Int8

  /// Remember that retrieving from the cache is more CPU-intensive than from a simple local variable.
  static let cache = Self(0)
}

@propertyWrapper
@MainActor public class UserDefault<T: DefaultsSerializable> {
  fileprivate let key: String
  private let getter: UserDefaultGetter<T> = UserDefaultGetter.standard
  private let defaultValue: T?
  private let lazyGetter: (() -> T)?
  private let transformGet: (T) -> T

  private let options: UserDefaultOptions
  private var _cachedValue: T.T?

  fileprivate var onSet: ((T) -> Void)?

  init(
    wrappedValue defaultValue: T,
    _ key: String,
    transformGet: @escaping (T) -> T = { $0 },
    options: UserDefaultOptions = []
  ) {
    self.key = key
    self.transformGet = transformGet
    self.options = options

    self.defaultValue = defaultValue
    self.lazyGetter = nil

    DefaultsInitStorage.preRegister(key, defaultValue)
  }
  init(
    wrappedValue lazyGetter: @escaping () -> T,
    _ key: String,
    transformGet: @escaping (T) -> T = { $0 },
    options: UserDefaultOptions = []
  ) {
    self.key = key
    self.transformGet = transformGet
    self.options = options

    self.defaultValue = nil
    self.lazyGetter = lazyGetter
  }

  fileprivate func reset() {
    let newValue = getCurrentValue()
    onSet?(newValue)
    if shouldCache {
      _cachedValue = newValue as? T.T
    }
  }

  private var shouldCache: Bool { options.contains(.cache) || GlobalDefaultsOptions.cacheAll }

  public var wrappedValue: T {
    get {
      guard _cachedValue == nil else { return _cachedValue as! T }

      let result = getCurrentValue()

      if shouldCache {
        _cachedValue = result as? T.T
      }

      return result
    }
    set {
      onSet?(newValue)
      if shouldCache {
        _cachedValue = transformGet(newValue) as? T.T
      }
      T._defaults.save(key: key, value: newValue as! T.T, userDefaults: UserDefaults.standard)
    }
  }

  public var projectedValue: UserDefaultWrapper<T> {
    UserDefaultWrapper(self)
  }

  private func getCurrentValue() -> T {
    let isUndefined = lazyGetter != nil && UserDefaults.standard.object(forKey: key) == nil
    let value = isUndefined ? lazyGetter!() : getter.getFunc(key) as! T

    return transformGet(value)
  }
}

public class UserDefaultWrapper<T: DefaultsSerializable> {
  private let userDefault: UserDefault<T>
  init(_ userDefault: UserDefault<T>) {
    self.userDefault = userDefault
  }

  @MainActor public func onSet(_ onSet: @escaping (T) -> Void) {
    userDefault.onSet = onSet
  }
  @MainActor public func delete(reset: Bool = true) {
    UserDefaults.standard.removeObject(forKey: userDefault.key)
    if reset { userDefault.reset() }
  }
}

@MainActor class Singleton {
  private static var instances: [ObjectIdentifier: Any] = [:]

  static var shared: Self {
    let key = ObjectIdentifier(self)
    if let existing = instances[key] as? Self {
      return existing
    }
    let newInstance = self.init()
    instances[key] = newInstance
    return newInstance
  }

  required init() {
    let key = ObjectIdentifier(type(of: self))
    guard Singleton.instances[key] == nil else {
      fatalError("\(Self.self) is a singleton! Use \(Self.self).shared instead.")
    }
    Singleton.instances[key] = self
  }
}


@propertyWrapper
struct Flag<T> {
  @MainActor let key = GlobalDefaultsOptions.onFlagInit()
  var defaultValue: T

  @MainActor init(wrappedValue: T) {
    self.defaultValue = wrappedValue
  }

  @MainActor var wrappedValue: T {
    get {
      return GlobalDefaultsOptions.shared.getFlag(forKey: key, defaultValue: defaultValue)
    }
    set {
      GlobalDefaultsOptions.shared.setFlag(forKey: key, value: newValue)
    }
  }
}

final class GlobalDefaultsOptions: Singleton {
  private var flags: [Int: Any] = [:]

  private var currentFlagId = 0
  fileprivate static func onFlagInit() -> Int {
    shared.currentFlagId += 1
    return shared.currentFlagId
  }

  required init() {}

  fileprivate func getFlag<T>(forKey key: Int, defaultValue: T) -> T {
    return flags[key] as? T ?? defaultValue
  }

  fileprivate func setFlag<T>(forKey key: Int, value: T) {
    flags[key] = value
  }
}

extension GlobalDefaultsOptions {
  /// Remember that retrieving from the cache is more CPU-intensive than from a simple local variable.
  @Flag static var cacheAll = false
}
