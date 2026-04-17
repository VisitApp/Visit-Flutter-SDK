import Flutter
import UIKit

public class VisitFlutterSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "visit_flutter_sdk", binaryMessenger: registrar.messenger())
    let instance = VisitFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "shareFile":
      shareFile(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func shareFile(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let filePath = arguments["path"] as? String,
          !filePath.isEmpty else {
      result(FlutterError(code: "invalid_arguments", message: "Missing file path.", details: nil))
      return
    }

    guard FileManager.default.fileExists(atPath: filePath) else {
      result(FlutterError(code: "file_not_found", message: "File does not exist.", details: filePath))
      return
    }

    DispatchQueue.main.async {
      guard let presenter = self.topViewController() else {
        result(FlutterError(code: "no_view_controller", message: "Unable to present share sheet.", details: nil))
        return
      }

      let activityViewController = UIActivityViewController(
        activityItems: [URL(fileURLWithPath: filePath)],
        applicationActivities: nil
      )

      if let popover = activityViewController.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 0,
          height: 0
        )
        popover.permittedArrowDirections = []
      }

      presenter.present(activityViewController, animated: true) {
        result(nil)
      }
    }
  }

  private func topViewController() -> UIViewController? {
    let rootViewController: UIViewController?

    if #available(iOS 13.0, *) {
      rootViewController = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController
    } else {
      rootViewController = UIApplication.shared.keyWindow?.rootViewController
    }

    return topViewController(from: rootViewController)
  }

  private func topViewController(from rootViewController: UIViewController?) -> UIViewController? {
    if let navigationController = rootViewController as? UINavigationController {
      return topViewController(from: navigationController.visibleViewController)
    }

    if let tabBarController = rootViewController as? UITabBarController {
      return topViewController(from: tabBarController.selectedViewController)
    }

    if let presentedViewController = rootViewController?.presentedViewController {
      return topViewController(from: presentedViewController)
    }

    return rootViewController
  }
}
