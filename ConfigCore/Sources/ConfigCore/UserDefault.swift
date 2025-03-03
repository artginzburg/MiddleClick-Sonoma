import Foundation

@MainActor protocol AnyUserDefault {
  associatedtype T: DefaultsSerializable
  var key: String? { get set }
  var defaultValue: T? { get }
}

@propertyWrapper
@MainActor public class UserDefault<T: DefaultsSerializable>: AnyUserDefault {
  var key: String?
  private let getter: UserDefaultGetter<T> = UserDefaultGetter.standard
  let defaultValue: T?
  private let lazyGetter: (() -> T)?
  private let transformGet: (T) -> T

  private let options: UserDefaultOptions
  private var _cachedValue: T.T?

  fileprivate var onSet: ((T) -> Void)?

  public init(
    wrappedValue defaultValue: T,
    _ key: String? = nil,
    transformGet: @escaping (T) -> T = { $0 },
    options: UserDefaultOptions = []
  ) {
    self.key = key
    self.transformGet = transformGet
    self.options = options

    self.defaultValue = defaultValue
    self.lazyGetter = nil

    if let key = key {
      DefaultsInitStorage.preRegister(key, defaultValue)
    }
  }
  public init(
    wrappedValue lazyGetter: @escaping () -> T,
    _ key: String? = nil,
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
      T._defaults.save(key: key!, value: newValue as! T.T, userDefaults: UserDefaults.standard)
    }
  }

  public var projectedValue: UserDefaultWrapper<T> {
    UserDefaultWrapper(self)
  }

  private func getCurrentValue() -> T {
    let isUndefined = lazyGetter != nil && UserDefaults.standard.object(forKey: key!) == nil
    let value = isUndefined ? lazyGetter!() : getter.getFunc(key!) as! T

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
    UserDefaults.standard.removeObject(forKey: userDefault.key!)
    if reset { userDefault.reset() }
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
