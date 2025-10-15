import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
screen mode id:i:2
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
}
