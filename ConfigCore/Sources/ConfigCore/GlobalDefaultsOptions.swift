public extension GlobalDefaultsOptions {
  /// Remember that retrieving from the cache is more CPU-intensive than from a simple local variable.
  @Flag static var cacheAll = false
}

@propertyWrapper
fileprivate struct Flag<T> {
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

final public class GlobalDefaultsOptions: Singleton {
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

