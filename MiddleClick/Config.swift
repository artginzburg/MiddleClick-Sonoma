import Foundation
import ConfigCore

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

  @UserDefault var tapToClick = getIsSystemTapToClickEnabled

  @UserDefault var ignoredAppBundles = Set<String>()
}

private func getIsSystemTapToClickEnabled() -> Bool {
  return CFPreferencesGetAppBooleanValue("Clicking" as CFString, "com.apple.driver.AppleBluetoothMultitouch.trackpad" as CFString, nil)
}
