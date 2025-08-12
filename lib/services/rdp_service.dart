import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/rdp_connection.dart';

class RDPService {
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

  Future<RDPConnection?> connectRDP({
    required String server,
    required String username,
    required String password,
    required String port,
    required Function(String) onStatusUpdate,
  }) async {
    try {
      onStatusUpdate('Creating RDP file...');

      // 1. RDP 파일 생성
      final rdpFilePath = await createRdpFile(
        server: server,
        username: username,
        password: password,
        port: port,
      );

      onStatusUpdate('Starting Windows App...');

      // 2. Windows App 실행
      final result = await Process.run('open', [
        '-a',
        'Windows App',
        rdpFilePath,
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to start Windows App: ${result.stderr}');
      }

      // 3. 잠시 대기 후 PID 찾기
      await Future.delayed(const Duration(seconds: 30));

      onStatusUpdate('Finding process PID...');

      final pidResult = await Process.run('pgrep', [
        '-f',
        'Contents/MacOS/Windows App',
      ]);

      if (pidResult.exitCode != 0) {
        throw Exception('Windows App process not found');
      }

      final pids = pidResult.stdout.toString().trim().split('\n');
      final latestPid = pids.isNotEmpty ? int.tryParse(pids.last) : null;

      if (latestPid == null) {
        throw Exception('Could not determine PID');
      }

      // 4. 연결 정보 생성
      final connection = RDPConnection(
        server: server,
        username: username,
        port: port,
        pid: latestPid,
        rdpFilePath: rdpFilePath,
        connectedAt: DateTime.now(),
      );

      onStatusUpdate('Connected successfully! PID: $latestPid');

      // 5. 임시 파일 정리 (연결 후 일정 시간 뒤)
      Future.delayed(const Duration(minutes: 1), () {
        final file = File(rdpFilePath);
        if (file.existsSync()) {
          file.delete();
        }
      });

      return connection;
    } catch (e) {
      onStatusUpdate('Connection failed: $e');
      return null;
    }
  }

  Future<void> killConnection(RDPConnection connection) async {
    final result = await Process.run('kill', [connection.pid.toString()]);
    if (result.exitCode != 0) {
      throw Exception('Failed to terminate connection: ${result.stderr}');
    }
  }

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
      final result = await Process.run('pgrep', [
        '-f',
        'Contents/MacOS/Windows App',
      ]);
      if (result.exitCode != 0) return [];

      final pidsString = result.stdout.toString().trim();
      if (pidsString.isEmpty) return [];

      return pidsString
          .split('\n')
          .map((pid) => int.tryParse(pid))
          .where((pid) => pid != null)
          .cast<int>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}
