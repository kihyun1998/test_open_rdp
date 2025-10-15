import 'dart:io';

import '../services/window_manager_service.dart';

/// Business logic for managing windows by PID
class PidWindowsManager {
  final WindowManagerService _windowManager = WindowManagerService();

  /// Fetches all windows for a given PID
  Future<PidWindowsResult> getWindowsForPid(int pid) async {
    try {
      final result = await _windowManager.getWindowsAppWindows();

      if (result.isSuccess && result.data != null) {
        final pidWindows = result.data!
            .where((window) => window.ownerPID == pid)
            .toList();

        return PidWindowsResult.success(pidWindows);
      } else {
        return PidWindowsResult.error(
          result.error?.toString() ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      return PidWindowsResult.error(e.toString());
    }
  }

  /// Filters windows to show only RDP connection windows
  List<WindowInfo> filterRdpWindows(List<WindowInfo> windows) {
    // RDP windows start with "connection_" pattern
    return windows.where((window) => isRdpConnectionWindow(window)).toList();
  }

  /// Checks if a window is an RDP connection window
  bool isRdpConnectionWindow(WindowInfo window) {
    return window.windowName.startsWith('connection_') &&
        window.windowName.contains(RegExp(r'connection_\d+'));
  }

  /// Gets windows that are not RDP connection windows
  List<WindowInfo> getNonRdpWindows(List<WindowInfo> windows) {
    return windows.where((window) => !isRdpConnectionWindow(window)).toList();
  }

  /// Filters windows by name pattern
  List<WindowInfo> filterWindowsByName(
    List<WindowInfo> windows,
    String namePattern,
  ) {
    return windows
        .where(
          (window) => window.windowName.toLowerCase().contains(
            namePattern.toLowerCase(),
          ),
        )
        .toList();
  }

  /// Detects new and removed windows by comparing with previous windows
  WindowChanges detectWindowChanges(
    List<WindowInfo> previousWindows,
    List<WindowInfo> currentWindows,
  ) {
    final previousIds = previousWindows.map((w) => w.windowId).toSet();
    final currentIds = currentWindows.map((w) => w.windowId).toSet();

    final newWindowIds = currentIds.difference(previousIds);
    final removedWindowIds = previousIds.difference(currentIds);

    return WindowChanges(
      newWindowIds: newWindowIds.toList(),
      removedWindowIds: removedWindowIds.toList(),
    );
  }

  /// Checks if a window ID is new compared to previous windows
  bool isNewWindow(int windowId, List<WindowInfo> previousWindows) {
    if (previousWindows.isEmpty) return false;
    return !previousWindows.any((w) => w.windowId == windowId);
  }

  /// Terminates a process with SIGTERM (graceful shutdown)
  Future<ProcessResult> terminateProcess(int pid) async {
    return await Process.run('kill', ['-TERM', '$pid']);
  }

  /// Force quits a process with SIGKILL
  Future<ProcessResult> forceQuitProcess(int pid) async {
    return await Process.run('kill', ['-9', '$pid']);
  }

  /// Gets the priority/type of a window based on its size
  String getWindowPriority(WindowInfo window) {
    final area = window.width * window.height;
    if (area > 500000) return 'Main';
    if (area > 100000) return 'Dialog';
    return 'UI';
  }

  /// Gets a description for window type based on area
  String getWindowTypeDescription(double area) {
    if (area > 500000) return '메인 창 (대형)';
    if (area > 100000) return '다이얼로그 창 (중형)';
    return 'UI 요소 창 (소형)';
  }

  /// Gets description for sharing state
  String getSharingStateDescription(int sharingState) {
    switch (sharingState) {
      case 0:
        return '🚫 공유 없음 (None)';
      case 1:
        return '👁️ 읽기 전용 (ReadOnly)';
      case 2:
        return '✏️ 읽기/쓰기 (ReadWrite)';
      default:
        return '❓ 알 수 없음 ($sharingState)';
    }
  }

  /// Formats memory usage in human-readable format
  String formatMemoryUsage(int bytes) {
    if (bytes == 0) return '정보 없음';
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Gets window info for a specific pattern with description
  WindowPatternInfo getWindowPatternInfo(String namePattern) {
    switch (namePattern.toLowerCase()) {
      case 'devices':
        return WindowPatternInfo(
          name: 'Devices',
          description: '📱 보통 디바이스 연결 창이나 USB 리디렉션 창입니다.',
        );
      case 'login':
        return WindowPatternInfo(
          name: 'login',
          description: '🔐 로그인 창이나 인증 창입니다.',
        );
      case 'dialog':
        return WindowPatternInfo(
          name: 'dialog',
          description: '💬 다양한 대화상자나 알림창입니다.',
        );
      case 'error':
        return WindowPatternInfo(
          name: 'error',
          description: '❌ 오류 메시지나 경고창입니다.',
        );
      default:
        return WindowPatternInfo(
          name: namePattern,
          description: '🪟 선택한 이름 패턴과 일치하는 창들입니다.',
        );
    }
  }
}

/// Result of fetching windows for a PID
class PidWindowsResult {
  final List<WindowInfo>? windows;
  final String? error;
  final bool isSuccess;

  PidWindowsResult._({this.windows, this.error, required this.isSuccess});

  factory PidWindowsResult.success(List<WindowInfo> windows) {
    return PidWindowsResult._(windows: windows, isSuccess: true);
  }

  factory PidWindowsResult.error(String error) {
    return PidWindowsResult._(error: error, isSuccess: false);
  }
}

/// Changes detected between window lists
class WindowChanges {
  final List<int> newWindowIds;
  final List<int> removedWindowIds;

  WindowChanges({required this.newWindowIds, required this.removedWindowIds});

  bool get hasChanges => newWindowIds.isNotEmpty || removedWindowIds.isNotEmpty;
}

/// Information about a window name pattern
class WindowPatternInfo {
  final String name;
  final String description;

  WindowPatternInfo({required this.name, required this.description});
}
