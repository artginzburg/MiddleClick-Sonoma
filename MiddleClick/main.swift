import Cocoa

private let app = NSApplication.shared

Controller().start()

private let menu = TrayMenu()
app.delegate = menu

app.run()
