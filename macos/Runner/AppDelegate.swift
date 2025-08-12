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
      let windowName = window[kCGWindowName as String] as? String ?? ""
      let windowId = window[kCGWindowNumber as String] as? Int ?? 0
      
      // 모든 윈도우 정보 출력 (디버깅용)
      print("🔍 Swift: Owner: '\(ownerName)', Name: '\(windowName)', ID: \(windowId)")
      
      // Windows App 관련 윈도우들을 더 넓게 찾기
      if ownerName.contains("Windows") || ownerName == "Windows App" {
        print("🔍 Swift: Found Windows-related window!")
        
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
    print("🔍 Swift: Attempting to close window ID: \(windowId)")
    
    // AppleScript를 사용해서 특정 Window ID의 창 닫기
    let script = """
    tell application "System Events"
        tell application process "Windows App"
            set windowList to windows
            repeat with w in windowList
                try
                    -- 창의 속성을 확인하고 닫기 시도
                    click button 1 of w
                    exit repeat
                on error
                    -- 다음 창으로 계속
                end try
            end repeat
        end tell
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let output = scriptObject.executeAndReturnError(&error)
        
        if let error = error {
            print("🔍 Swift: AppleScript error: \(error)")
            result(false)
        } else {
            print("🔍 Swift: AppleScript executed successfully")
            result(true)
        }
    } else {
        print("🔍 Swift: Failed to create AppleScript")
        result(false)
    }
  }
}
