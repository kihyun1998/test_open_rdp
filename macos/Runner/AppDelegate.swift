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
    
    // 창 정보를 가져와서 분석
    let windowList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as! [[String: Any]]
    
    guard let windowInfo = windowList.first,
          let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
          let x = bounds["X"] as? Double,
          let y = bounds["Y"] as? Double,
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double else {
      print("📷 Failed to get window bounds")
      result(nil)
      return
    }
    
    // 창 속성 분석
    let windowName = windowInfo[kCGWindowName as String] as? String ?? ""
    let windowLayer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
    let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? ""
    
    print("📷 Window info - Name: '\(windowName)', Layer: \(windowLayer), Owner: '\(ownerName)'")
    
    // titlebar 높이 동적 계산
    var titlebarHeight: Double = 0
    
    // 1. 전체화면 감지 (화면 크기와 비교)
    let screenFrame = NSScreen.main?.frame ?? NSRect.zero
    let isFullscreen = (width >= screenFrame.width - 10 && height >= screenFrame.height - 10)
    
    // 2. 창 레이어 확인 (0이면 일반 창, 다른 값이면 특수 창)
    let isNormalWindow = (windowLayer == 0)
    
    // 3. 창 이름으로 특수 창 감지
    let isSpecialWindow = windowName.isEmpty || 
                         windowName.contains("Dock") || 
                         windowName.contains("Desktop") ||
                         windowName.contains("Wallpaper")
    
    if isFullscreen {
      titlebarHeight = 0
      print("📷 Detected fullscreen window - no titlebar")
    } else if !isNormalWindow || isSpecialWindow {
      titlebarHeight = 0
      print("📷 Detected special window - no titlebar")
    } else {
      // 일반 창인 경우 titlebar 높이 계산
      // macOS Big Sur 이후: 28px, 이전: 22px
      if #available(macOS 11.0, *) {
        titlebarHeight = 28
      } else {
        titlebarHeight = 22
      }
      print("📷 Detected normal window - titlebar height: \(titlebarHeight)")
    }
    
    let contentRect = CGRect(
      x: x,
      y: y + titlebarHeight,
      width: width,
      height: max(0, height - titlebarHeight)
    )
    
    print("📷 Capture rect: \(contentRect)")
    
    guard let image = CGWindowListCreateImage(
      contentRect,
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
      print("📷 Captured \(data.count) bytes (titlebar: \(titlebarHeight)px)")
      result(FlutterStandardTypedData(bytes: data))
    } else {
      print("📷 Failed to finalize PNG")
      result(nil)
    }
  }
}
