import Flutter
import UIKit

final class SpracheInboundIntentBridge {
  static let shared = SpracheInboundIntentBridge()

  private let channelName = "com.youkdonghun.sprache/inbound_intent"
  private let maxInboundBytes = 32 * 1024 * 1024
  private var channel: FlutterMethodChannel?
  private var pendingIntent: String?

  private init() {}

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "getInitialInboundIntent":
        let initial = self.pendingIntent
        self.pendingIntent = nil
        result(initial)
      case "readInboundFile":
        self.readInboundFile(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func receive(_ url: URL) {
    let raw = url.absoluteString
    if let channel {
      channel.invokeMethod("onInboundIntent", arguments: raw)
    } else {
      pendingIntent = raw
    }
  }

  private func readInboundFile(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let arguments = call.arguments as? [String: Any],
      let raw = arguments["uri"] as? String,
      let url = URL(string: raw),
      url.isFileURL
    else {
      result(FlutterError(code: "unsafe_uri", message: "Only file URLs are accepted", details: nil))
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let declaredSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
      if let declaredSize, declaredSize <= 0 || declaredSize > maxInboundBytes {
        result(FlutterError(code: "unsafe_size", message: "The inbound file size is not accepted", details: nil))
        return
      }
      let handle = try FileHandle(forReadingFrom: url)
      defer { try? handle.close() }
      let data = handle.readData(ofLength: maxInboundBytes + 1)
      guard !data.isEmpty, data.count <= maxInboundBytes else {
        result(FlutterError(code: "unsafe_size", message: "The inbound file size is not accepted", details: nil))
        return
      }
      result([
        "name": url.lastPathComponent,
        "bytes": FlutterStandardTypedData(bytes: data),
      ])
    } catch {
      result(FlutterError(code: "read_failed", message: error.localizedDescription, details: nil))
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpracheInboundIntent")
    SpracheInboundIntentBridge.shared.attach(to: registrar.messenger())
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    SpracheInboundIntentBridge.shared.receive(url)
    return true
  }
}
