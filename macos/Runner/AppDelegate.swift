import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Menubar app: closing/hiding the window must not quit the app.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Launching the app again only re-activates this instance. With no Dock icon
  // and the window hidden, nothing would appear — and if the tray icon was lost
  // there would be no way back in. So hand it to Dart to recover.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    NativeBridge.notifyReopen()
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
