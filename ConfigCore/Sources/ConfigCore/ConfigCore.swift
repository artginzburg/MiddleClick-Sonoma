import CoreFoundation

// Huge thanks to https://github.com/sunshinejr/SwiftyUserDefaults .
// I found it too late, but some parts of it, like the DefaultsBridge, are just gold.

/**
 Extend this class to define your Config

 ```swift
 final class Config: ConfigCore { ... }
 ```
 # Usage
 - Define your keys (without `static`):
 ```swift
 //                  \ key /
 @UserDefault var minimumFingers = 3 // <- default value
 // Under the hood, this means:
 UserDefaults.standard.register(defaults: ["minimumFingers": 3])
 ```
 - Use them via `.shared`:
 ```swift
 let fingersQuantity = Config.shared.minimumFingers
 ```
 - More options you can discover, using auto-completions on ``UserDefault``:
   - automatic key inference
   - caching
   - using a function as the default value (waits until the property is first accessed)
   - using a key different from the variable name: `@UserDefault("fingers")`

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
    super.init()

    let mirror = Mirror(reflecting: self)
    for child in mirror.children {
      guard var userDefault = child.value as? (any AnyUserDefault) else { continue } // Skip - not a UserDefault
      guard userDefault.key == nil else { continue } // Skip - already has an explicit key
      guard let label = child.label else {
        fatalError("Could not get child.label in Mirror (ConfigCore)")
        continue
      }

      let key = transformLabelToKey(label)
      userDefault.key = key

      guard let defaultValue = userDefault.defaultValue else { continue } // Skip - no default value, or default value is lazy
      DefaultsInitStorage.preRegister(key, defaultValue)
    }

    DefaultsInitStorage.register()
  }

  private func transformLabelToKey(_ label: String) -> String {
    return String(label.dropFirst())
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

