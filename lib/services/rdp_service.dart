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

      // 1. 실행 전 기존 PID 목록 저장
      final existingPids = await getAllWindowsAppPids();
      onStatusUpdate('Found ${existingPids.length} existing Windows App processes');

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
        '-n',  // 새 인스턴스 강제 실행
        '-a',
        'Windows App',
        rdpFilePath,
      ]);

      if (result.exitCode != 0) {
        throw Exception('Failed to start Windows App: ${result.stderr}');
      }

      // 4. 새로운 PID 찾기 (폴링 방식)
      onStatusUpdate('Waiting for new process to start...');
      onStatusUpdate('Existing PIDs: ${existingPids.join(", ")}');
      int? newPid;
      
      for (int attempt = 1; attempt <= 10; attempt++) {
        await Future.delayed(const Duration(seconds: 3));
        onStatusUpdate('Looking for new process (attempt $attempt/10)...');
        
        final currentPids = await getAllWindowsAppPids();
        onStatusUpdate('Current PIDs: ${currentPids.join(", ")}');
        
        final newPids = currentPids.where((pid) => !existingPids.contains(pid)).toList();
        onStatusUpdate('New PIDs found: ${newPids.join(", ")}');
        
        if (newPids.isNotEmpty) {
          newPid = newPids.last; // 가장 최근 PID 사용
          onStatusUpdate('Selected new process PID: $newPid');
          break;
        } else {
          onStatusUpdate('No new PIDs found in attempt $attempt');
        }
      }

      if (newPid == null) {
        // 새 PID를 찾지 못한 경우, 기존 방식으로 폴백
        onStatusUpdate('Could not find new process, using fallback method...');
        final allPids = await getAllWindowsAppPids();
        if (allPids.isNotEmpty) {
          newPid = allPids.last;
          onStatusUpdate('Using latest process PID: $newPid');
        } else {
          throw Exception('No Windows App process found');
        }
      }

      // 5. 연결 정보 생성
      final connection = RDPConnection(
        server: server,
        username: username,
        port: port,
        pid: newPid,
        rdpFilePath: rdpFilePath,
        connectedAt: DateTime.now(),
      );

      onStatusUpdate('Windows App launched with PID: $newPid. Check connection status manually.');

      // 6. 임시 파일 정리 (연결 후 일정 시간 뒤)
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
      print('ps -p $pid exit code: ${result.exitCode}');
      if (result.exitCode != 0) {
        print('ps -p $pid stderr: "${result.stderr}"');
      }
      return result.exitCode == 0;
    } catch (e) {
      print('Error checking if process $pid is alive: $e');
      return false;
    }
  }

  Future<List<int>> getAllWindowsAppPids() async {
    try {
      // pgrep 대신 ps 명령어 사용 (권한 문제 해결)
      final result = await Process.run('ps', [
        'aux',
      ]);
      
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
        '-p', pid.toString(),
        '-i', 'TCP',
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
        '-p', pid.toString(),
        '-o', 'pid,ppid,state,etime,command'
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
