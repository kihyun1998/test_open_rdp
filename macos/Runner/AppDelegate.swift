import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

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
      case "captureWindow":
        if let args = call.arguments as? [String: Any],
           let windowId = args["windowId"] as? Int {
          self?.captureWindow(windowId: windowId, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func getWindowsAppWindows(result: @escaping FlutterResult) {
    let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
    var windowsAppWindows: [[String: Any]] = []
    
    for window in windowList {
      let ownerName = window[kCGWindowOwnerName as String] as? String ?? "Unknown"
      let windowName = window[kCGWindowName as String] as? String ?? ""
      let windowId = window[kCGWindowNumber as String] as? Int ?? 0
      
      // Windows App 관련 윈도우들을 더 넓게 찾기
      if ownerName.contains("Windows") || ownerName == "Windows App" {
        let ownerPID = window[kCGWindowOwnerPID as String] as? Int ?? 0
        
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
    
    result(windowsAppWindows)
  }
  
  private func closeWindow(windowId: Int, result: @escaping FlutterResult) {
    print("🔥 Closing window: \(windowId)")
    
    let script = """
    tell application "Windows App"
        activate
    end tell
    delay 0.2
    tell application "System Events"
        tell process "Windows App"
            click button 1 of front window
        end tell
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        let output = scriptObject.executeAndReturnError(&error)
        
        if error == nil {
            print("🔥 Success")
            result(true)
        } else {
            print("🔥 Failed: \(error!)")
            result(false)
        }
    } else {
        result(false)
    }
  }
  
  private func captureWindow(windowId: Int, result: @escaping FlutterResult) {
    print("📷 Capturing window: \(windowId)")
    
    let windowID = CGWindowID(windowId)
    
    guard let image = CGWindowListCreateImage(
      CGRect.null,
      .optionIncludingWindow,
      windowID,
      .bestResolution
    ) else {
      print("📷 Failed to create image for window \(windowId)")
      result(nil)
      return
    }
    
    guard let pngData = CFDataCreateMutable(nil, 0),
          let destination = CGImageDestinationCreateWithData(pngData, kUTTypePNG, 1, nil) else {
      print("📷 Failed to create PNG data")
      result(nil)
      return
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    
    if CGImageDestinationFinalize(destination) {
      let data = Data(referencing: pngData)
      print("📷 Captured \(data.count) bytes")
      result(FlutterStandardTypedData(bytes: data))
    } else {
      print("📷 Failed to finalize PNG")
      result(nil)
    }
  }
}
