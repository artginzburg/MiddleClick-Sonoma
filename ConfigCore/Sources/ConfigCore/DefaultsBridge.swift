import Foundation

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
