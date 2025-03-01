import Foundation

// Huge thanks to https://github.com/sunshinejr/SwiftyUserDefaults .
// I found it too late, but some parts of it, like the DefaultsBridge, are just gold.

// TODO rewrite this
enum UserDefaultGetter<T: DefaultsSerializable> {
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
@MainActor open class ConfigCore: Singleton {
  public static let options = GlobalDefaultsOptions.self

  required public init() {
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

public struct UserDefaultOptions: OptionSetInt {
  public init(rawValue: Int8) {
    self.rawValue = rawValue
  }
  public let rawValue: Int8

  /// Remember that retrieving from the cache is more CPU-intensive than from a simple local variable.
  @MainActor public static let cache = Self(0)
}

@MainActor open class Singleton {
  private static var instances: [ObjectIdentifier: Any] = [:]

  public static var shared: Self {
    let key = ObjectIdentifier(self)
    if let existing = instances[key] as? Self {
      return existing
    }
    let newInstance = self.init()
    instances[key] = newInstance
    return newInstance
  }

  required public init() {
    let key = ObjectIdentifier(type(of: self))
    guard Singleton.instances[key] == nil else {
      fatalError("\(Self.self) is a singleton! Use \(Self.self).shared instead.")
    }
    Singleton.instances[key] = self
  }
}

