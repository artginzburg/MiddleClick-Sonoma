import Foundation
import ConfigCore

let kCGMouseButtonCenter: Int64 = 2

final class Config: ConfigCore {
  required init() {
    Self.options.cacheAll = true
  }

  @UserDefault("fingers")
  var minimumFingers = 3

  @UserDefault var allowMoreFingers = false

  @UserDefault var maxDistanceDelta: Float = 0.05

  /// In milliseconds
  @UserDefault(transformGet: { $0 / 1000 })
  var maxTimeDelta: Double = 300

  /// inverted "Tap to Click" flag
  @UserDefault var needClick = getIsSystemTapToClickDisabled

  @UserDefault var ignoredAppBundles = Set<String>()
}

func getIsSystemTapToClickDisabled() -> Bool {
  let clickingEnabled = CFPreferencesCopyAppValue("Clicking" as CFString, "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString) as? Int ?? 1
  return clickingEnabled == 0
}
