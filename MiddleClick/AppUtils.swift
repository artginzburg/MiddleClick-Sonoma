import Cocoa

@MainActor
final class AppUtils {
  static func getFocusedApp() -> NSRunningApplication? {
    return NSWorkspace.shared.frontmostApplication
  }

  /// Caveat: Depends on getFocusedApp(), but the cursor may actually be above a window that is not currently focused, in which case a middle-click will pass through to an "Ignored" application.
  static func isIgnoredAppBundle() -> Bool {
    guard let bundleId = getFocusedApp()?.bundleIdentifier else { return false }
    return GlobalState.shared.ignoredAppBundlesCache.contains(bundleId)
  }
}
