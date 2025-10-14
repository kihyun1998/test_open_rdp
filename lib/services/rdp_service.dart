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
      // 1. Windows App 설치 확인
      onStatusUpdate('Checking Windows App installation...');
      final isInstalled = await isWindowsAppInstalled();
      if (!isInstalled) {
        print('❌ Windows App not found on this system');
        return ConnectionResult(
          type: ConnectionResultType.appNotFound,
          message: 'Windows App is not installed on this system',
          error: 'Please install Windows App from the App Store',
        );
      }
      print('✅ Windows App found - ready to launch');

      // 2. RDP 파일 생성
      onStatusUpdate('Creating RDP file...');
      final rdpFilePath = await createRdpFile(
        server: server,
        username: username,
        password: password,
        port: port,
      );

      // 3. Windows App 실행
      onStatusUpdate('Starting Windows App...');
      final result = await Process.run('open', [
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

      // 4. Windows App PID 대기
      onStatusUpdate('Waiting for Windows App to launch...');
      final pid = await _waitForWindowsAppPid();
      if (pid == null) {
        return ConnectionResult(
          type: ConnectionResultType.appError,
          message: 'Failed to find Windows App process',
        );
      }
      onStatusUpdate('Windows App running with PID: $pid');

      // 5. PID로 필터링하여 RDP Window 찾기
      onStatusUpdate('Looking for RDP window...');
      final windowId = await _findWindowByPidAndFileName(pid, rdpFilePath);

      if (windowId == null) {
        return ConnectionResult(
          type: ConnectionResultType.appError,
          message: 'Failed to find RDP window - connection may have failed',
        );
      }

      // 6. 연결 정보 생성
      final connection = RDPConnection(
        server: server,
        username: username,
        port: port,
        windowId: windowId,
        pid: pid,
        rdpFilePath: rdpFilePath,
        connectedAt: DateTime.now(),
      );

      onStatusUpdate(
        'RDP window created! Window ID: $windowId, PID: $pid',
      );

      // 7. 임시 파일 정리 (연결 후 일정 시간 뒤)
      Future.delayed(const Duration(minutes: 1), () {
        final file = File(rdpFilePath);
        if (file.existsSync()) {
          file.delete();
        }
      });

      return ConnectionResult(
        type: ConnectionResultType.success,
        connection: connection,
        message: 'RDP connection successful! Window ID: $windowId, PID: $pid',
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

  /// Windows App PID를 찾을 때까지 대기 (최대 10초)
  Future<int?> _waitForWindowsAppPid() async {
    for (int attempt = 1; attempt <= 10; attempt++) {
      final result = await Process.run('pgrep', ['-x', 'Windows App']);
      if (result.exitCode == 0) {
        final pidStr = result.stdout.toString().trim();
        final pid = int.tryParse(pidStr);
        if (pid != null) {
          return pid;
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// 특정 PID가 소유한 Window 중에서 RDP 파일명과 매칭되는 Window ID 찾기
  Future<int?> _findWindowByPidAndFileName(int pid, String rdpFilePath) async {
    final rdpFileName = path.basenameWithoutExtension(rdpFilePath);

    // 최대 10번 시도 (새 창이 나타날 때까지 대기)
    for (int attempt = 1; attempt <= 10; attempt++) {
      final windowsResult = await _windowManager.getWindowsAppWindows();
      if (!windowsResult.isSuccess) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      final allWindows = windowsResult.data ?? [];

      // PID가 일치하고 RDP 파일명이 제목에 포함된 Window 찾기
      final matchingWindows = allWindows.where((w) {
        final pidMatch = w.ownerPID == pid;
        final titleMatch = w.windowName.toLowerCase().contains(rdpFileName.toLowerCase());
        return pidMatch && titleMatch;
      }).toList();

      if (matchingWindows.isNotEmpty) {
        // 매칭된 창 중 가장 큰 창 선택
        final targetWindow = matchingWindows.reduce((a, b) {
          final areaA = a.width * a.height;
          final areaB = b.width * b.height;
          return areaA > areaB ? a : b;
        });
        return targetWindow.windowId;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    return null;
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

  /// RDP 파일명으로 실제 창을 찾아서 연결 정보를 업데이트
  Future<RDPConnection?> findAndUpdateConnection(RDPConnection connection) async {
    try {
      // Windows App PID 찾기
      final pid = await _waitForWindowsAppPid();
      if (pid == null) {
        return null;
      }

      // PID와 파일명으로 Window 찾기
      final windowId = await _findWindowByPidAndFileName(pid, connection.rdpFilePath);
      if (windowId == null) {
        return null;
      }

      // 연결 정보 업데이트
      return RDPConnection(
        server: connection.server,
        username: connection.username,
        port: connection.port,
        windowId: windowId,
        pid: pid,
        rdpFilePath: connection.rdpFilePath,
        connectedAt: connection.connectedAt,
      );
    } catch (e) {
      return null;
    }
  }
}
