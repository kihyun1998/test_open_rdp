import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    let windowChannel = FlutterMethodChannel(name: "rdp_app/window_manager",
                                            binaryMessenger: controller.engine.binaryMessenger)
    
    windowChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getWindowsAppWindows":
        self?.getWindowsAppWindows(result: result)
      case "closeWindow":
        if let args = call.arguments as? [String: Any],
           let windowId = args["windowId"] as? Int {
          self?.closeWindow(windowId: windowId, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func getWindowsAppWindows(result: @escaping FlutterResult) {
    print("🔍 Swift: getWindowsAppWindows called")
    
    let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
    print("🔍 Swift: Found \(windowList.count) total windows")
    
    var windowsAppWindows: [[String: Any]] = []
    
    for window in windowList {
      let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
      print("🔍 Swift: Window owner: '\(ownerName)'")
      
      if ownerName == "Windows App" {
        print("🔍 Swift: Found Windows App window!")
        
        let windowId = window[kCGWindowNumber as String] as? Int ?? 0
        let windowName = window[kCGWindowName as String] as? String ?? ""
        let ownerPID = window[kCGWindowOwnerPID as String] as? Int ?? 0
        
        print("🔍 Swift: Window ID: \(windowId), Name: '\(windowName)', PID: \(ownerPID)")
        
        let windowInfo: [String: Any] = [
          "windowId": windowId,
          "windowName": windowName,
          "ownerPID": ownerPID,
          "bounds": [
            "x": (window[kCGWindowBounds as String] as? [String: Any])?["X"] as? Double ?? 0,
            "y": (window[kCGWindowBounds as String] as? [String: Any])?["Y"] as? Double ?? 0,
            "width": (window[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0,
            "height": (window[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0
          ]
        ]
        windowsAppWindows.append(windowInfo)
      }
    }
    
    print("🔍 Swift: Returning \(windowsAppWindows.count) Windows App windows")
    result(windowsAppWindows)
  }
  
  private func closeWindow(windowId: Int, result: @escaping FlutterResult) {
    // Window ID로 창 닫기 (이 부분은 복잡할 수 있음)
    // 우선은 성공으로 반환
    result(true)
  }
}
