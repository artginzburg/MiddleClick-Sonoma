import Cocoa

private let app = NSApplication.shared

private let con = Controller()
con.start()

private let menu = TrayMenu(controller: con)
app.delegate = menu

app.run()
