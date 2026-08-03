import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ sender: NSApplication, open urls: [URL]) {
    // FlutterAppDelegate dispatches Google OAuth callbacks to the registered
    // google_sign_in plugin. Sprache deep links remain owned by our bridge.
    super.application(sender, open: urls)
    for url in urls where isSpracheInboundURL(url) {
      SpracheInboundIntentBridge.shared.receive(url)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

private func isSpracheInboundURL(_ url: URL) -> Bool {
  url.scheme?.caseInsensitiveCompare("sprache") == .orderedSame
}
