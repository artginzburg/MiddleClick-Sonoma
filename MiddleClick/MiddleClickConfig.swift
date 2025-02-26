import Foundation

let kCGMouseButtonCenter: Int64 = 2

final class Config: ConfigCore {
  required init() {
    Self.options.cacheAll = true
  }

  @UserDefault("fingers", default: 3)
  var minimumFingers

  @UserDefault("allowMoreFingers", default: false)
  var allowMoreFingers

  @UserDefault("maxDistanceDelta", default: 0.05)
  var maxDistanceDelta: Float

  /// In milliseconds
  @UserDefault("maxTimeDelta", default: 300, transformGet: { $0 / 1000 })
  var maxTimeDelta: Double

  /// inverted "Tap to Click" flag
  @UserDefault("needClick", default: getIsSystemTapToClickDisabled)
  var needClick

  @UserDefault("ignoredAppBundles", default: Set<String>())
  var ignoredAppBundles
}

func getIsSystemTapToClickDisabled() -> Bool {
  let clickingEnabled = CFPreferencesCopyAppValue("Clicking" as CFString, "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString) as? Int ?? 1
  return clickingEnabled == 0
}
