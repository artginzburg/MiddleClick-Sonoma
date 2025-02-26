import Cocoa

let app = NSApplication.shared

let con = Controller()
con.start()

let menu = TrayMenu(controller: con)
app.delegate = menu

app.run()
