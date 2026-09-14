import Flutter
import UIKit

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
    // With the implicit (UIScene) engine, plugins are registered after
    // application(_:didFinishLaunchingWithOptions:) has already run, so
    // firebase_messaging misses the launch callback where it asks iOS for an
    // APNs token. Register now that the plugin is listening for the token.
    UIApplication.shared.registerForRemoteNotifications()
  }
}
