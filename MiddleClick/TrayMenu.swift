import Cocoa
import ServiceManagement

@MainActor final class TrayMenu: NSObject, NSApplicationDelegate {
  private var infoItem, tapToClickItem, accessibilityPermissionStatusItem, accessibilityPermissionActionItem, ignoredAppItem, launchAtLoginItem: NSMenuItem!
  private var statusItem: NSStatusItem!

  @objc private func initAccessibilityPermissionStatus(menu: NSMenu) {
    let hasAccessibilityPermission = SystemPermissions.detectAccessibilityIsGranted(forcePrompt: true)

    updateAccessibilityPermissionStatus(
      menu: menu, hasAccessibilityPermission: hasAccessibilityPermission)

    if !hasAccessibilityPermission {
      Timer
        .scheduledTimer(
          timeInterval: 0.3,
          target: self,
          selector: #selector(initAccessibilityPermissionStatus(menu:)),
          userInfo: nil,
          repeats: false
        )
    }
  }

  private func updateAccessibilityPermissionStatus(menu: NSMenu, hasAccessibilityPermission: Bool) {
    statusItem.button?.appearsDisabled = !hasAccessibilityPermission
    accessibilityPermissionStatusItem.isHidden = hasAccessibilityPermission
    accessibilityPermissionActionItem.isHidden = hasAccessibilityPermission
  }

  @objc private func openWebsite(sender: Any) {
    if let url = URL(string: "https://github.com/artginzburg/MiddleClick-Sonoma") {
      NSWorkspace.shared.open(url)
    }
  }

  @objc private func openAccessibilitySettings(sender: Any) {
    let isPreCatalina =
      (floor(NSAppKitVersion.current.rawValue) < NSAppKitVersion.macOS10_15.rawValue)
    if isPreCatalina {
      let appleScript = """
        tell application "System Preferences"
        activate
        reveal anchor "Privacy_Accessibility" of pane "com.apple.preference.security"
        end tell
        """
      if let script = NSAppleScript(source: appleScript) {
        script.executeAndReturnError(nil)
      }
    } else {
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      {
        NSWorkspace.shared.open(url)
      }
    }
  }

  @objc private func toggleTapToClick(sender: NSButton) {
    Config.shared.tapToClick = sender.state == .off
    setChecks()
  }

  @objc private func resetTapToClick(sender: NSButton) {
    Config.shared.$tapToClick.delete()
    setChecks()
  }

  private func setChecks() {
    let tapToClick = Config.shared.tapToClick
    let clickModeInfo = "Click" + (tapToClick ? " or Tap" : "")

    let fingersQua = Config.shared.minimumFingers
    let allowMoreFingers = Config.shared.allowMoreFingers
    let fingersInfo = " with \(fingersQua)\(allowMoreFingers ? "+" : "") Fingers"

    infoItem.title = clickModeInfo + fingersInfo
    tapToClickItem.state = tapToClick ? .on : .off
  }

  @objc private func actionQuit(sender: Any) {
    NSApp.terminate(sender)
  }

  private func createMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self

    createMenuAccessibilityPermissionItems(menu: menu)

    ignoredAppItem = menu
      .addItem(
        withTitle: "Ignore focused app",
        action: #selector(ignoreApp),
        keyEquivalent: ""
      )
    menu.addItem(.separator())

    infoItem = menu.addItem(withTitle: "", action: nil, keyEquivalent: "")
    infoItem.target = self

    tapToClickItem = menu.addItem(
      withTitle: "Tap to click", action: #selector(toggleTapToClick), keyEquivalent: "")
    tapToClickItem.target = self

    let resetItem = menu.addItem(
      withTitle: "Reset to System Settings", action: #selector(resetTapToClick(sender:)),
      keyEquivalent: "")
    resetItem.isAlternate = true
    resetItem.keyEquivalentModifierMask = .option
    resetItem.target = self

    setChecks()

    menu.addItem(NSMenuItem.separator())

    launchAtLoginItem = menu.addItem(
      withTitle: "Launch at login",
      action: #selector(toggleLoginItem),
      keyEquivalent: ""
    )
    updateLaunchAtLoginItem()

    let aboutItem = menu.addItem(
      withTitle: "About \(getAppName())...", action: #selector(openWebsite(sender:)),
      keyEquivalent: "")
    aboutItem.target = self

    let quitItem = menu.addItem(
      withTitle: "Quit", action: #selector(actionQuit(sender:)), keyEquivalent: "q")
    quitItem.target = self

    return menu
  }

  private func createMenuAccessibilityPermissionItems(menu: NSMenu) {
    accessibilityPermissionStatusItem = menu.addItem(
      withTitle: "Missing Accessibility permission", action: nil, keyEquivalent: "")
    accessibilityPermissionActionItem = menu.addItem(
      withTitle: "Open Privacy Preferences", action: #selector(openAccessibilitySettings(sender:)),
      keyEquivalent: ",")
    menu.addItem(NSMenuItem.separator())
  }

  private func getAppName() -> String {
    return ProcessInfo.processInfo.processName
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let menu = createMenu()

    let icon = NSImage(named: "StatusIcon") ?? NSImage()
    icon.size = CGSize(width: 24, height: 24)  // TODO? increase size

    let oldBusted = (floor(NSAppKitVersion.current.rawValue) <= NSAppKitVersion.macOS10_9.rawValue)
    if !oldBusted {
      icon.isTemplate = true
    }

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.behavior = .removalAllowed
    statusItem.menu = menu
    statusItem.button?.toolTip = getAppName()
    statusItem.button?.image = icon

    initAccessibilityPermissionStatus(menu: menu)
  }

  #if DEBUG
  private var timesHandledReopen = 0
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
    if let focusedAppName = AppUtils.getFocusedApp()?.localizedName {
      ignoredAppItem.title = "Ignore " + focusedAppName
      ignoredAppItem.state = AppUtils.isIgnoredAppBundle() ? .on : .off
    }
  }

  @objc private func ignoreApp(sender: Any) {
    guard let focusedBundleID = AppUtils.getFocusedApp()?.bundleIdentifier else { return }

    GlobalState.shared.ignoredAppBundlesCache.formSymmetricDifference([focusedBundleID])

    Config.shared.ignoredAppBundles = GlobalState.shared.ignoredAppBundlesCache
  }
}
