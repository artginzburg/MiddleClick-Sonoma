import Cocoa

private let app = NSApplication.shared

UserDefaultsMigration.migrateIfNeeded()

let controller = Controller()
controller.start()

private let menu = TrayMenu()
#if DEBUG
menu.restartListeners = controller.restartListeners
#endif

app.delegate = menu

app.run()
