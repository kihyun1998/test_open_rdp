import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/rdp_connection.dart';
import '../models/connection_result.dart';
import 'window_manager_service.dart';

class RDPService {
  final WindowManagerService _windowManager = WindowManagerService();
  Future<String> createRdpFile({
    required String server,
    required String username,
    required String password,
    required String port,
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'connection_$timestamp.rdp';
      final filePath = path.join(directory.path, fileName);

      final rdpContent =
          '''full address:s:$server:$port
username:s:$username
password 51:b:${_encodePassword(password)}
prompt for credentials:i:0
administrative session:i:0
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
winposstr:s:0,1,0,0,800,600
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:''';

      final file = File(filePath);
      await file.writeAsString(rdpContent);
      return filePath;
    } catch (e) {
      throw Exception('Failed to create RDP file: $e');
    }
  }

  String _encodePassword(String password) {
    // 간단한 base64 인코딩 (실제로는 Windows App이 처리)
    // 실제 구현에서는 더 안전한 방법을 사용해야 함
    return password;
  }

  Future<bool> isWindowsAppInstalled() async {
    try {
      // 1. 파일 시스템 체크
      final appDir = Directory('/Applications/Windows App.app');
      if (await appDir.exists()) {
        return true;
      }

      // 2. mdfind로 검색 (Spotlight 데이터베이스)
      final result = await Process.run('mdfind', [
        'kMDItemDisplayName == "Windows App" && kMDItemKind == "Application"'
      ]);
      
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<ConnectionResult> connectRDP({
    required String server,
    required String username,
    required String password,
    required String port,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      // 0. Windows App 설치 확인
      onStatusUpdate('Checking Windows App installation...');
      final isInstalled = await isWindowsAppInstalled();
      if (!isInstalled) {
        return ConnectionResult(
          type: ConnectionResultType.appNotFound,
          message: 'Windows App is not installed on this system',
          error: 'Please install Windows App from the App Store',
        );
      }

      onStatusUpdate('Creating RDP file...');

      // 1. 실행 전 기존 Window 목록 저장
      final existingWindowsResult = await _windowManager.getWindowsAppWindows();
      if (!existingWindowsResult.isSuccess) {
        throw Exception(
          'Failed to get existing windows: ${existingWindowsResult.error}',
        );
      }
      final existingWindows = existingWindowsResult.data ?? [];
      onStatusUpdate(
        'Found ${existingWindows.length} existing Windows App windows',
      );
      final existingWindowIds = existingWindows.map((w) => w.windowId).toSet();

      // 2. RDP 파일 생성
      final rdpFilePath = await createRdpFile(
        server: server,
        username: username,
        password: password,
        port: port,
      );

      onStatusUpdate('Starting Windows App...');

      // 3. Windows App 실행 (새 인스턴스 강제 실행)
      final result = await Process.run('open', [
        // '-n', // 새 인스턴스 강제 실행
        '-a',
        'Windows App',
        rdpFilePath,
      ]);

      if (result.exitCode != 0) {
        final errorMsg = result.stderr.toString();
        if (errorMsg.contains('Unable to find application')) {
          return ConnectionResult(
            type: ConnectionResultType.appNotFound,
            message: 'Windows App not found during execution',
            error: errorMsg,
          );
        }
        return ConnectionResult(
          type: ConnectionResultType.commandFailed,
          message: 'Failed to execute open command',
          error: errorMsg,
        );
      }

      // 4. 새로운 Window 찾기 (폴링 방식)
      onStatusUpdate('Waiting for new window to appear...');
      WindowInfo? newWindow;

      for (int attempt = 1; attempt <= 10; attempt++) {
        await Future.delayed(const Duration(seconds: 3));
        onStatusUpdate('Looking for new window (attempt $attempt/10)...');

        final currentWindowsResult = await _windowManager
            .getWindowsAppWindows();
        if (!currentWindowsResult.isSuccess) {
          onStatusUpdate(
            'Failed to get current windows: ${currentWindowsResult.error}',
          );
          continue;
        }
        final currentWindows = currentWindowsResult.data ?? [];
        onStatusUpdate('Found ${currentWindows.length} total windows');

        // 새로운 윈도우 찾기
        final newWindows = currentWindows
            .where((w) => !existingWindowIds.contains(w.windowId))
            .toList();

        if (newWindows.isNotEmpty) {
          // 가장 큰 창을 RDP 메인 창으로 선택 (면적 기준)
          newWindow = newWindows.reduce((a, b) {
            final areaA = a.width * a.height;
            final areaB = b.width * b.height;
            return areaA > areaB ? a : b;
          });
          onStatusUpdate(
            'Found new RDP window: ID ${newWindow.windowId}, Size: ${newWindow.width.toInt()}x${newWindow.height.toInt()}',
          );
          break;
        } else {
          onStatusUpdate('No new windows found in attempt $attempt');
        }
      }

      if (newWindow == null) {
        // 새 창이 없으면 기존 창이 포커싱됐거나 앱 오류
        final currentWindowsResult = await _windowManager.getWindowsAppWindows();
        if (currentWindowsResult.isSuccess) {
          final currentWindows = currentWindowsResult.data ?? [];
          if (currentWindows.isNotEmpty) {
            // 기존 창이 있으면 포커싱된 것으로 판단
            return ConnectionResult(
              type: ConnectionResultType.existingFocused,
              message: 'Existing Windows App window was focused (${currentWindows.length} windows found)',
            );
          }
        }
        
        // 창이 없으면 Windows App 내부 오류
        return ConnectionResult(
          type: ConnectionResultType.appError,
          message: 'Windows App failed to create new window - possible internal error',
        );
      }

      // 5. 연결 정보 생성
      final connection = RDPConnection(
        server: server,
        username: username,
        port: port,
        windowId: newWindow.windowId,
        pid: newWindow.ownerPID,
        rdpFilePath: rdpFilePath,
        connectedAt: DateTime.now(),
      );

      onStatusUpdate(
        'RDP window created! Window ID: ${newWindow.windowId}, PID: ${newWindow.ownerPID}',
      );

      // 6. 임시 파일 정리 (연결 후 일정 시간 뒤)
      Future.delayed(const Duration(minutes: 1), () {
        final file = File(rdpFilePath);
        if (file.existsSync()) {
          file.delete();
        }
      });

      return ConnectionResult(
        type: ConnectionResultType.success,
        connection: connection,
        message: 'RDP window created successfully! Window ID: ${newWindow.windowId}, PID: ${newWindow.ownerPID}',
      );
    } catch (e) {
      onStatusUpdate('Connection failed: $e');
      return ConnectionResult(
        type: ConnectionResultType.appError,
        message: 'Connection failed due to unexpected error',
        error: e.toString(),
      );
    }
  }

  Future<void> killConnection(RDPConnection connection) async {
    // Window ID로 창 닫기 시도
    final windowClosedResult = await _windowManager.closeWindow(
      connection.windowId,
    );
    if (!windowClosedResult.isSuccess || windowClosedResult.data != true) {
      // Window 닫기가 실패하면 프로세스 종료로 폴백 (전체 앱이 종료될 수 있음)
      final result = await Process.run('kill', [connection.pid.toString()]);
      if (result.exitCode != 0) {
        throw Exception('Failed to terminate connection: ${result.stderr}');
      }
    }
  }

  Future<bool> isWindowAlive(int windowId) async {
    final result = await _windowManager.isWindowAlive(windowId);
    return result.isSuccess && (result.data ?? false);
  }

  // 기존 PID 기반 메서드도 유지 (호환성)
  Future<bool> isProcessAlive(int pid) async {
    try {
      final result = await Process.run('ps', ['-p', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<List<int>> getAllWindowsAppPids() async {
    try {
      // pgrep 대신 ps 명령어 사용 (권한 문제 해결)
      final result = await Process.run('ps', ['aux']);

      print('ps exit code: ${result.exitCode}');

      if (result.exitCode != 0) {
        print('ps stderr: "${result.stderr}"');
        return [];
      }

      final lines = result.stdout.toString().split('\n');
      final pids = <int>[];

      for (final line in lines) {
        if (line.contains('Windows App.app/Contents/MacOS/Windows App') &&
            !line.contains('grep')) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            final pid = int.tryParse(parts[1]); // PID는 두 번째 컬럼
            if (pid != null) {
              pids.add(pid);
            }
          }
        }
      }

      print('Found Windows App PIDs: $pids');
      return pids;
    } catch (e) {
      print('Error in getAllWindowsAppPids: $e');
      return [];
    }
  }

  /// 프로세스의 상세 정보를 확인하여 실제 RDP 연결인지 판단
  Future<bool> isRDPConnection(int pid) async {
    try {
      // lsof를 사용하여 네트워크 연결 확인
      final lsofResult = await Process.run('lsof', [
        '-p',
        pid.toString(),
        '-i',
        'TCP',
      ]);

      if (lsofResult.exitCode == 0) {
        final output = lsofResult.stdout.toString();
        // 3389 포트 연결이 있는지 확인
        return output.contains(':3389') || output.contains('ESTABLISHED');
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 프로세스가 실제로 활성 상태인지 더 자세히 확인
  Future<String> getProcessDetails(int pid) async {
    try {
      final result = await Process.run('ps', [
        '-p',
        pid.toString(),
        '-o',
        'pid,ppid,state,etime,command',
      ]);

      if (result.exitCode == 0) {
        return result.stdout.toString();
      }

      return 'Process not found';
    } catch (e) {
      return 'Error getting process details: $e';
    }
  }
}
