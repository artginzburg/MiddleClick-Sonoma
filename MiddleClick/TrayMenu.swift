import Cocoa

@MainActor final class TrayMenu: NSObject, NSApplicationDelegate {
  private var infoItem, tapToClickItem, accessibilityPermissionStatusItem, accessibilityPermissionActionItem, ignoredAppItem: NSMenuItem!
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
    Config.shared.needClick = sender.state == .on
    setChecks()
  }

  @objc private func resetTapToClick(sender: NSButton) {
    Config.shared.$needClick.delete()
    setChecks()
  }

  private func setChecks() {
    let clickMode = Config.shared.needClick
    let clickModeInfo = "Click" + (clickMode ? "" : " or Tap")

    let fingersQua = Config.shared.minimumFingers
    let allowMoreFingers = Config.shared.allowMoreFingers
    let fingersInfo = " with \(fingersQua)\(allowMoreFingers ? "+" : "") Fingers"

    infoItem.title = clickModeInfo + fingersInfo
    tapToClickItem.state = clickMode ? .off : .on
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

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    statusItem.isVisible = true
    return true
  }
}


extension TrayMenu: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    updateIgnoredAppItem()
  }

  private func updateIgnoredAppItem() {
    if let focusedAppName = getFocusedApp()?.localizedName {
      ignoredAppItem.title = "Ignore " + focusedAppName
      ignoredAppItem.state = isIgnoredAppBundle() ? .on : .off
    }
  }

  @objc private func ignoreApp(sender: Any) {
    guard let focusedBundleID = getFocusedApp()?.bundleIdentifier else { return }

    ignoredAppBundlesCache.formSymmetricDifference([focusedBundleID])

    Config.shared.ignoredAppBundles = ignoredAppBundlesCache
  }
}
