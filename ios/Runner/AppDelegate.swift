import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // プッシュ通知の登録
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // Dart 側からバッジをクリアするための MethodChannel
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(
        name: "com.sofvo.app/badge",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { (call, result) in
        if call.method == "clearBadge" {
          Self.clearBadge()
          result(nil)
        } else if call.method == "setBadge", let args = call.arguments as? [String: Any], let count = args["count"] as? Int {
          Self.setBadge(count)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // アプリがフォアグラウンドに来た時に通知センターを掃除する。
  // ⚠️ ここでバッジを 0 にしてはいけない。未読チャットが残っている
  // 状態で 0 にすると「アプリ内 3 件未読・iOS バッジ 0」のズレが
  // 発生する。バッジは Dart 側 (PushNotificationService.updateBadgeCount)
  // が AppLifecycleState.resumed をフックして実際の未読数で再計算する。
  override func applicationDidBecomeActive(_ application: UIApplication) {
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    super.applicationDidBecomeActive(application)
  }

  // iOS 17+ 対応のバッジクリア（非推奨 API を回避）
  // Dart 側からの clearBadge MethodChannel 呼び出しから利用する。
  static func clearBadge() {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(0) { error in
        if let error = error {
          print("Failed to clear badge: \(error)")
        }
      }
    } else {
      UIApplication.shared.applicationIconBadgeNumber = 0
    }
    // 配信済み通知も削除（通知センターから消去）
    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
  }

  static func setBadge(_ count: Int) {
    if #available(iOS 16.0, *) {
      UNUserNotificationCenter.current().setBadgeCount(count) { error in
        if let error = error {
          print("Failed to set badge: \(error)")
        }
      }
    } else {
      UIApplication.shared.applicationIconBadgeNumber = count
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // APNsトークンをFirebase Messagingに渡す
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(application, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
