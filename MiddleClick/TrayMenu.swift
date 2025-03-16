import ServiceManagement
import AppKit

@MainActor final class TrayMenu: NSObject {
  private let config = Config.shared
  private var infoItem, tapToClickItem, accessibilityPermissionStatusItem, accessibilityPermissionActionItem, ignoredAppItem, launchAtLoginItem: NSMenuItem!
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

  override init() {
    super.init()

    if Self.shouldDelayInit {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self.initSequence()
      }
    } else {
      self.initSequence()
    }
  }
  private func initSequence() {
    setupStatusItem()
    initAccessibilityPermissionStatus()
  }
  
  #if DEBUG
  private static let shouldDelayInit = terminateExistingInstance(force: false)
  #else
  private static let shouldDelayInit = false
  #endif

  private var hasForcePrompted = false

  @objc private func initAccessibilityPermissionStatus() {
    let hasAccessibilityPermission = SystemPermissions.detectAccessibilityIsGranted(
      forcePrompt: !hasForcePrompted
    )
    hasForcePrompted = true

    updateAccessibilityPermissionStatus(hasAccessibilityPermission)

    if !hasAccessibilityPermission {
      Timer
        .scheduledTimer(
          timeInterval: 0.3,
          target: self,
          selector: #selector(initAccessibilityPermissionStatus),
          userInfo: nil,
          repeats: false
        )
    }
  }

  private func updateAccessibilityPermissionStatus(_ hasAccessibilityPermission: Bool) {
    statusItem.button?.appearsDisabled = !hasAccessibilityPermission
    accessibilityPermissionStatusItem.isHidden = hasAccessibilityPermission
    accessibilityPermissionActionItem.isHidden = hasAccessibilityPermission
  }

  private func updateTapToClickStatus() {
    let tapToClick = config.tapToClick
    let clickModeInfo = "Click" + (tapToClick ? " or Tap" : "")
    let fingersInfo = " with \(config.minimumFingers)\(config.allowMoreFingers ? "+" : "") Fingers"

    infoItem.title = clickModeInfo + fingersInfo
    tapToClickItem.state = tapToClick ? .on : .off
  }

  private func createMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    createMenuAccessibilityPermissionItems(menu)

    ignoredAppItem = menu
      .addItem(
        withTitle: "Ignore focused app",
        action: #selector(ignoreApp),
        target: self
      )
    menu.addSeparator()

    infoItem = menu.addItem(withTitle: "")

    tapToClickItem = menu.addItem(
      withTitle: "Tap to click", action: #selector(toggleTapToClick), target: self)

    let resetItem = menu.addItem(
      withTitle: "Reset to System Settings", action: #selector(resetTapToClick), target: self)
    resetItem.isAlternate = true
    resetItem.keyEquivalentModifierMask = .option

    updateTapToClickStatus()

    menu.addSeparator()

    launchAtLoginItem = menu.addItem(
      withTitle: "Launch at login",
      action: #selector(toggleLoginItem),
      target: self
    )
    updateLaunchAtLoginItem()

    #if DEBUG
    _ = menu.addItem(
      withTitle: "Restart listeners",
      action: #selector(restartNow),
      target: self,
      keyEquivalent: "r"
    )
    #endif

    _ = menu.addItem(
      withTitle: "About \(getAppName())...", action: #selector(openWebsite), target: self)

    _ = menu.addItem(
      withTitle: "Quit", action: #selector(actionQuit), target: self, keyEquivalent: "q")

    return menu
  }

  private func createMenuAccessibilityPermissionItems(_ menu: NSMenu) {
    accessibilityPermissionStatusItem = menu.addItem(
      withTitle: "Missing Accessibility permission")
    accessibilityPermissionActionItem = menu.addItem(
      withTitle: "Open Privacy Preferences", action: #selector(openAccessibilitySettings), target: self,
      keyEquivalent: ",")
    menu.addSeparator()
  }

  private func getAppName() -> String {
    return ProcessInfo.processInfo.processName
  }

  private func setupStatusItem() {
    statusItem.behavior = .removalAllowed
    statusItem.menu = createMenu()
    statusItem.button?.toolTip = getAppName()
    statusItem.button?.image = createStatusIcon()
  }

  private func createStatusIcon() -> NSImage? {
    guard let icon = NSImage(named: "StatusIcon") else { return nil }
    icon.size = CGSize(width: 25, height: 25)
    icon.isTemplate = true
    return icon
  }

  #if DEBUG
  private var timesHandledReopen = 0
  var restartListeners: (() -> Void)?
  #endif
}

#if DEBUG
// MARK: Dev-only
extension TrayMenu {
  private static func terminateExistingInstance(force: Bool = true) -> Bool {
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).filter {
      $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }

    for app in runningApps {
      log.info("Terminating existing instance of MiddleClick (PID: \(app.processIdentifier))")
      if force { return app.forceTerminate() } else { return app.terminate() }
    }

    return runningApps.count > 0
  }
}
#endif

// MARK: Actions
extension TrayMenu {
  @objc private func openWebsite() {
    if let url = URL(string: "https://github.com/artginzburg/MiddleClick-Sonoma") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func openAccessibilitySettings() {
    if #available(macOS 10.15, *) {
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      {
        NSWorkspace.shared.open(url)
      }
    } else {
      let appleScript = """
        tell application "System Preferences"
          activate
          reveal anchor "Privacy_Accessibility" of pane "com.apple.preference.security"
        end tell
        """
      if let script = NSAppleScript(source: appleScript) {
        script.executeAndReturnError(nil)
      }
    }
  }

  @objc private func toggleTapToClick(sender: NSButton) {
    config.tapToClick = sender.state == .off
    updateTapToClickStatus()
  }

  @objc private func resetTapToClick() {
    config.$tapToClick.delete()
    updateTapToClickStatus()
  }

  @objc private func actionQuit(sender: Any) {
    NSApp.terminate(sender)
  }

  #if DEBUG
  @objc private func restartNow() {
    restartListeners?()
  }
  #endif
}

extension TrayMenu: NSApplicationDelegate {
  #if DEBUG
    private func isRunningInXcode() -> Bool {
      return ProcessInfo.processInfo.environment["IDE_DISABLED_OS_ACTIVITY_DT_MODE"] != nil
    }
  #endif

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
    {
  #if DEBUG
      guard !isRunningInXcode() || timesHandledReopen >= 2 else {
        timesHandledReopen += 1
        return true
      }
  #endif

      statusItem.isVisible = true
      Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
        DispatchQueue.main.async {
          self.statusItem.button?.performClick(nil)
        }
      }

      return true
    }
}

// Launch at login:
extension TrayMenu {
  @objc private func toggleLoginItem() {
    modifyLoginItem(add: launchAtLoginItem.state == .off)
    updateLaunchAtLoginItem()
  }
  private func updateLaunchAtLoginItem() {
    launchAtLoginItem.state = isLoginItemEnabled() ? .on : .off
  }
  private func isLoginItemEnabled() -> Bool {
    if #available(macOS 13.0, *) {
      return SMAppService.mainApp.status == .enabled
    } else {
      let appName = getAppName()
      let script = """
        tell application "System Events" to get name of login item "\(appName)"
        """

      if let appleScript = NSAppleScript(source: script) {
        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)

        if errorDict != nil {
          return false
        }

        return result.stringValue == appName
      }

      return false
    }
  }
  private func modifyLoginItem(add: Bool) {
    if #available(macOS 13.0, *) {
      do {
        if add {
          try SMAppService.mainApp.register()
        } else {
          try SMAppService.mainApp.unregister()
        }
      } catch {
        log.error("Failed to \(add ? "add" : "remove") to login items: \(error)")
      }
    } else {
      let appName = getAppName()
      let script = add ?
        """
        tell application "System Events" to make login item at end with properties {path:"/Applications/\(appName).app", hidden:true}
        """ :
        """
        tell application "System Events" to delete login item "\(appName)"
        """

      if let appleScript = NSAppleScript(source: script) {
        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)

        if let error = errorDict {
          log.error("Failed to \(add ? "add" : "remove") \(appName) from login items: \(error)")
        }
      }
    }
  }
}

extension TrayMenu: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    updateIgnoredAppItem()
  }

  private func updateIgnoredAppItem() {
    let focusedApp = AppUtils.getFocusedApp()
    if let focusedAppName = focusedApp?.localizedName {
      ignoredAppItem.title = "Ignore " + focusedAppName
      ignoredAppItem.state = AppUtils.isIgnoredAppBundle(focusedApp) ? .on : .off
    }
  }

  @objc private func ignoreApp() {
    guard let focusedBundleID = AppUtils.getFocusedApp()?.bundleIdentifier else { return }

    config.ignoredAppBundles.formSymmetricDifference([focusedBundleID])
  }
}

extension NSMenu {
  func addItem(withTitle string: String, action selector: Selector, target: AnyObject, keyEquivalent charCode: String = "") -> NSMenuItem {
    let menuItem = NSMenuItem(title: string, action: selector, keyEquivalent: charCode)
    menuItem.target = target
    self.addItem(menuItem)
    return menuItem
  }
  func addItem(withTitle string: String) -> NSMenuItem {
    return self.addItem(withTitle: string, action: nil, keyEquivalent: "")
  }

  func addSeparator() {
    self.addItem(.separator())
  }
}
