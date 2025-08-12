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
      print('🔍 Flutter: Calling getWindowsAppWindows...');
      final List<dynamic> result = await _channel.invokeMethod('getWindowsAppWindows');
      print('🔍 Flutter: Got ${result.length} windows from Swift');
      
      final windows = result.map((window) {
        print('🔍 Flutter: Window data: $window');
        // 안전한 타입 변환
        final windowMap = Map<String, dynamic>.from(window as Map);
        return WindowInfo.fromMap(windowMap);
      }).toList();
      
      print('🔍 Flutter: Parsed ${windows.length} WindowInfo objects');
      for (final window in windows) {
        print('🔍 Flutter: $window');
      }
      
      return windows;
    } catch (e) {
      print('❌ Flutter: Error getting Windows App windows: $e');
      return [];
    }
  }

  /// 특정 Window ID로 창을 닫습니다
  Future<bool> closeWindow(int windowId) async {
    try {
      final bool result = await _channel.invokeMethod('closeWindow', {'windowId': windowId});
      return result;
    } catch (e) {
      print('Error closing window $windowId: $e');
      return false;
    }
  }

  /// Window ID가 여전히 존재하는지 확인합니다
  Future<bool> isWindowAlive(int windowId) async {
    final windows = await getWindowsAppWindows();
    return windows.any((window) => window.windowId == windowId);
  }
}