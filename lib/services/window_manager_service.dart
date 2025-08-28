import 'package:flutter/services.dart';
import 'package:macos_window_toolkit/macos_window_toolkit.dart';

class WindowManagerError {
  final String message;
  final String? details;
  final dynamic originalError;

  WindowManagerError({required this.message, this.details, this.originalError});

  @override
  String toString() => details != null ? '$message: $details' : message;
}

class WindowManagerResult<T> {
  final T? data;
  final WindowManagerError? error;
  final bool isSuccess;

  WindowManagerResult.success(this.data) : error = null, isSuccess = true;

  WindowManagerResult.failure(this.error) : data = null, isSuccess = false;
}

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

  factory WindowInfo.fromMacosWindowInfo(MacosWindowInfo macosWindow) {
    return WindowInfo(
      windowId: macosWindow.windowId,
      windowName: macosWindow.name,
      ownerPID: macosWindow.processId,
      x: macosWindow.x,
      y: macosWindow.y,
      width: macosWindow.width,
      height: macosWindow.height,
    );
  }

  @override
  String toString() {
    return 'WindowInfo(id: $windowId, name: "$windowName", pid: $ownerPID, bounds: ${width}x$height)';
  }
}

class WindowManagerService {
  final MacosWindowToolkit _toolkit = MacosWindowToolkit();

  /// Windows App의 모든 창 정보를 가져옵니다
  Future<WindowManagerResult<List<WindowInfo>>> getWindowsAppWindows() async {
    try {
      final allWindows = await _toolkit.getAllWindows();

      final windowsAppWindows = allWindows
          .where(
            (window) =>
                window.ownerName.contains('Windows') ||
                window.ownerName == 'Windows App',
          )
          .map((window) => WindowInfo.fromMacosWindowInfo(window))
          .toList();

      return WindowManagerResult.success(windowsAppWindows);
    } on PlatformException catch (e) {
      final error = WindowManagerError(
        message: 'macOS 창 목록을 가져올 수 없습니다',
        details: 'Screen Recording 권한이 필요할 수 있습니다',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    } catch (e) {
      final error = WindowManagerError(
        message: '창 목록 조회 중 오류가 발생했습니다',
        details: e.toString(),
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    }
  }

  /// 특정 Window ID로 창을 닫습니다
  Future<WindowManagerResult<bool>> closeWindow(int windowId) async {
    try {
      print('🔥 Closing window ID: $windowId');
      final result = await _toolkit.closeWindow(windowId);
      print('🔥 Close result: $result');
      return WindowManagerResult.success(result);
    } on PlatformException catch (e) {
      final error = WindowManagerError(
        message: '창을 닫을 수 없습니다',
        details: 'Accessibility 권한이 필요하거나 창이 이미 닫혔을 수 있습니다',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    } catch (e) {
      final error = WindowManagerError(
        message: '창 닫기 중 오류가 발생했습니다',
        details: 'Window ID $windowId: ${e.toString()}',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    }
  }

  /// Window ID가 여전히 존재하는지 확인합니다
  Future<WindowManagerResult<bool>> isWindowAlive(int windowId) async {
    try {
      final result = await _toolkit.isWindowAlive(windowId);
      return WindowManagerResult.success(result);
    } on PlatformException catch (e) {
      final error = WindowManagerError(
        message: '창 상태를 확인할 수 없습니다',
        details: 'Screen Recording 권한이 필요할 수 있습니다',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    } catch (e) {
      final error = WindowManagerError(
        message: '창 상태 확인 중 오류가 발생했습니다',
        details: 'Window ID $windowId: ${e.toString()}',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    }
  }

  /// 특정 Window ID의 스크린샷을 캡처합니다
  Future<WindowManagerResult<Uint8List>> captureWindow(int windowId) async {
    try {
      print('📷 Capturing window ID: $windowId');
      final result = await _toolkit.captureWindow(windowId);

      switch (result) {
        case CaptureSuccess(imageData: final data):
          print('📷 Capture result: ${data.length} bytes');
          return WindowManagerResult.success(data);
        case CaptureFailure(reason: final reason):
          print('❌ Capture failed: $reason');
          final error = WindowManagerError(
            message: '화면 캡처에 실패했습니다',
            details: _getCaptureFailureMessage(reason),
            originalError: reason,
          );
          return WindowManagerResult.failure(error);
      }
    } on PlatformException catch (e) {
      final error = WindowManagerError(
        message: '화면 캡처를 할 수 없습니다',
        details: 'Screen Recording 권한이 필요합니다',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    } catch (e) {
      final error = WindowManagerError(
        message: '화면 캡처 중 오류가 발생했습니다',
        details: 'Window ID $windowId: ${e.toString()}',
        originalError: e,
      );
      return WindowManagerResult.failure(error);
    }
  }

  String _getCaptureFailureMessage(CaptureFailureReason reason) {
    switch (reason) {
      case CaptureFailureReason.windowMinimized:
        return '창이 최소화되어 있어 캡처할 수 없습니다';
      case CaptureFailureReason.windowNotFound:
        return '창을 찾을 수 없습니다';
      case CaptureFailureReason.permissionDenied:
        return 'Screen Recording 권한이 거부되었습니다';
      case CaptureFailureReason.unknown:
        return '알 수 없는 오류가 발생했습니다';
      case CaptureFailureReason.unsupportedVersion:
        return '지원되지 않는 macOS 버전입니다';
      case CaptureFailureReason.captureInProgress:
        return '이미 캡처가 진행 중입니다';
      case CaptureFailureReason.windowNotCapturable:
        return '캡처할 수 없는 창입니다';
      default:
        return '알 수 없는 오류가 발생했습니다';
    }
  }
}
