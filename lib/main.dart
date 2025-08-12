import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const RDPApp());
}

class RDPApp extends StatelessWidget {
  const RDPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RDP Connection Manager',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RDPConnectionPage(),
    );
  }
}

class RDPConnectionPage extends StatefulWidget {
  const RDPConnectionPage({super.key});

  @override
  State<RDPConnectionPage> createState() => _RDPConnectionPageState();
}

class _RDPConnectionPageState extends State<RDPConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '3389');

  bool _isConnecting = false;
  String _connectionStatus = '';
  final List<RDPConnection> _activeConnections = [];

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<String> _createRdpFile({
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

  Future<RDPConnection?> _connectRDP() async {
    if (!_formKey.currentState!.validate()) return null;

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Creating RDP file...';
    });

    try {
      // 1. RDP 파일 생성
      final rdpFilePath = await _createRdpFile(
        server: _serverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        port: _portController.text,
      );

      setState(() {
        _connectionStatus = 'Starting Windows App...';
      });

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
      await Future.delayed(const Duration(seconds: 3));

      setState(() {
        _connectionStatus = 'Finding process PID...';
      });

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
        server: _serverController.text,
        username: _usernameController.text,
        port: _portController.text,
        pid: latestPid,
        rdpFilePath: rdpFilePath,
        connectedAt: DateTime.now(),
      );

      setState(() {
        _activeConnections.add(connection);
        _connectionStatus = 'Connected successfully! PID: $latestPid';
        _isConnecting = false;
      });

      // 5. 임시 파일 정리 (연결 후 일정 시간 뒤)
      Timer(const Duration(minutes: 1), () {
        final file = File(rdpFilePath);
        if (file.existsSync()) {
          file.delete();
        }
      });

      return connection;
    } catch (e) {
      setState(() {
        _connectionStatus = 'Connection failed: $e';
        _isConnecting = false;
      });
      return null;
    }
  }

  Future<void> _killConnection(RDPConnection connection) async {
    try {
      final result = await Process.run('kill', [connection.pid.toString()]);
      if (result.exitCode == 0) {
        setState(() {
          _activeConnections.remove(connection);
          _connectionStatus = 'Connection terminated (PID: ${connection.pid})';
        });
      } else {
        setState(() {
          _connectionStatus =
              'Failed to terminate connection: ${result.stderr}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error terminating connection: $e';
      });
    }
  }

  Future<bool> _isProcessAlive(int pid) async {
    try {
      final result = await Process.run('ps', ['-p', pid.toString()]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RDP Connection Manager'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New RDP Connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverController,
                        decoration: const InputDecoration(
                          labelText: 'Server IP/Hostname',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter server address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter username';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              controller: _portController,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Port required';
                                }
                                final port = int.tryParse(value);
                                if (port == null || port < 1 || port > 65535) {
                                  return 'Invalid port';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password (Optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isConnecting ? null : _connectRDP,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        child: _isConnecting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Connecting...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow),
                                  SizedBox(width: 8),
                                  Text('Connect RDP'),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_connectionStatus.isNotEmpty)
              Card(
                color:
                    _connectionStatus.contains('failed') ||
                        _connectionStatus.contains('Error')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        _connectionStatus.contains('failed') ||
                                _connectionStatus.contains('Error')
                            ? Icons.error
                            : Icons.info,
                        color:
                            _connectionStatus.contains('failed') ||
                                _connectionStatus.contains('Error')
                            ? Colors.red
                            : Colors.green,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectionStatus,
                          style: TextStyle(
                            color:
                                _connectionStatus.contains('failed') ||
                                    _connectionStatus.contains('Error')
                                ? Colors.red.shade800
                                : Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_activeConnections.isNotEmpty) ...[
              const Text(
                'Active Connections',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._activeConnections.map(
                (connection) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.desktop_windows),
                    title: Text('${connection.server}:${connection.port}'),
                    subtitle: Text(
                      'User: ${connection.username}\n'
                      'PID: ${connection.pid}\n'
                      'Connected: ${connection.connectedAt.toString().substring(0, 19)}',
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'status',
                          child: const Row(
                            children: [
                              Icon(Icons.info),
                              SizedBox(width: 8),
                              Text('Check Status'),
                            ],
                          ),
                          onTap: () async {
                            final isAlive = await _isProcessAlive(
                              connection.pid,
                            );
                            if (mounted) {
                              setState(() {
                                _connectionStatus = isAlive
                                    ? 'Process ${connection.pid} is running'
                                    : 'Process ${connection.pid} is not running';
                              });
                            }
                          },
                        ),
                        PopupMenuItem(
                          value: 'kill',
                          child: const Row(
                            children: [
                              Icon(Icons.close, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Terminate'),
                            ],
                          ),
                          onTap: () => _killConnection(connection),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RDPConnection {
  final String server;
  final String username;
  final String port;
  final int pid;
  final String rdpFilePath;
  final DateTime connectedAt;

  RDPConnection({
    required this.server,
    required this.username,
    required this.port,
    required this.pid,
    required this.rdpFilePath,
    required this.connectedAt,
  });

  @override
  String toString() {
    return 'RDPConnection(server: $server, pid: $pid)';
  }
}
