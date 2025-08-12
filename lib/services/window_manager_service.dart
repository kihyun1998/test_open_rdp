import 'dart:typed_data';
import 'package:flutter/services.dart';

class WindowInfo {
  final int windowId;
  final String windowName;
  final int ownerPID;
  final double x, y, width, height;

  WindowInfo({
    required this.windowId,
    required this.windowName,
    required this.ownerPID,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory WindowInfo.fromMap(Map<String, dynamic> map) {
    final boundsRaw = map['bounds'];
    final bounds = Map<String, dynamic>.from(boundsRaw as Map);
    
    return WindowInfo(
      windowId: map['windowId'] as int,
      windowName: map['windowName'] as String,
      ownerPID: map['ownerPID'] as int,
      x: (bounds['x'] as num).toDouble(),
      y: (bounds['y'] as num).toDouble(),
      width: (bounds['width'] as num).toDouble(),
      height: (bounds['height'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'WindowInfo(id: $windowId, name: "$windowName", pid: $ownerPID, bounds: ${width}x$height)';
  }
}

class WindowManagerService {
  static const MethodChannel _channel = MethodChannel('rdp_app/window_manager');

  /// Windows App의 모든 창 정보를 가져옵니다
  Future<List<WindowInfo>> getWindowsAppWindows() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getWindowsAppWindows');
      
      final windows = result.map((window) {
        // 안전한 타입 변환
        final windowMap = Map<String, dynamic>.from(window as Map);
        return WindowInfo.fromMap(windowMap);
      }).toList();
      
      return windows;
    } catch (e) {
      print('❌ Error getting Windows App windows: $e');
      return [];
    }
  }

  /// 특정 Window ID로 창을 닫습니다
  Future<bool> closeWindow(int windowId) async {
    try {
      print('🔥 Closing window ID: $windowId');
      final bool result = await _channel.invokeMethod('closeWindow', {'windowId': windowId});
      print('🔥 Close result: $result');
      return result;
    } catch (e) {
      print('❌ Error closing window $windowId: $e');
      return false;
    }
  }

  /// Window ID가 여전히 존재하는지 확인합니다
  Future<bool> isWindowAlive(int windowId) async {
    final windows = await getWindowsAppWindows();
    return windows.any((window) => window.windowId == windowId);
  }

  /// 특정 Window ID의 스크린샷을 캡처합니다
  Future<Uint8List?> captureWindow(int windowId) async {
    try {
      print('📷 Capturing window ID: $windowId');
      final Uint8List? result = await _channel.invokeMethod('captureWindow', {'windowId': windowId});
      print('📷 Capture result: ${result?.length ?? 0} bytes');
      return result;
    } catch (e) {
      print('❌ Error capturing window $windowId: $e');
      return null;
    }
  }
}