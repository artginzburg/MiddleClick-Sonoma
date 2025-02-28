import Cocoa

private let app = NSApplication.shared

let controller = Controller()
controller.start()

private let menu = TrayMenu()
app.delegate = menu

app.run()
