import 'dart:io';

import 'package:flutter/material.dart';

import '../models/captured_image.dart';
import '../services/rdp_service.dart';
import '../services/window_manager_service.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_form.dart';
import '../widgets/pid_windows_list.dart';
import '../widgets/status_message.dart';

class RDPConnectionPage extends StatefulWidget {
  const RDPConnectionPage({super.key});

  @override
  State<RDPConnectionPage> createState() => _RDPConnectionPageState();
}

class _RDPConnectionPageState extends State<RDPConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController(text: "192.168.136.136");
  final _usernameController = TextEditingController(text: "Administrator");
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '3389');
  final _rdpService = RDPService();
  final _windowManager = WindowManagerService();

  bool _isConnecting = false;
  String _connectionStatus = '';
  int? _windowsAppPid;
  String? _rdpFilePath;
  final List<CapturedImage> _capturedImages = [];

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectRDP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Checking Windows App installation...';
    });

    try {
      // 1. Windows App 설치 확인
      final isInstalled = await _rdpService.isWindowsAppInstalled();
      if (!isInstalled) {
        setState(() {
          _connectionStatus = '🚫 Windows App is not installed';
          _isConnecting = false;
        });
        return;
      }

      // 2. RDP 파일 생성
      setState(() {
        _connectionStatus = 'Creating RDP file...';
      });

      final rdpFilePath = await _rdpService.createRdpFile(
        server: _serverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        port: _portController.text,
      );

      // 3. Windows App 실행
      setState(() {
        _connectionStatus = 'Starting Windows App...';
      });

      final result = await Process.run('open', [
        '-a',
        'Windows App',
        rdpFilePath,
      ]);

      if (result.exitCode != 0) {
        setState(() {
          _connectionStatus =
              '❌ Failed to launch Windows App: ${result.stderr}';
          _isConnecting = false;
        });
        return;
      }

      // 4. Windows App PID 대기
      setState(() {
        _connectionStatus = 'Waiting for Windows App to launch...';
      });

      final pid = await _waitForWindowsAppPid();

      if (pid == null) {
        setState(() {
          _connectionStatus = '⚠️ Failed to find Windows App process';
          _isConnecting = false;
        });
        return;
      }

      // 5. 성공
      setState(() {
        _windowsAppPid = pid;
        _rdpFilePath = rdpFilePath;
        _connectionStatus = '✅ Connected! Windows App PID: $pid';
        _isConnecting = false;
      });

      // 6. 임시 파일 정리 (1분 후)
      Future.delayed(const Duration(minutes: 1), () {
        final file = File(rdpFilePath);
        if (file.existsSync()) {
          file.delete();
        }
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Connection failed: $e';
        _isConnecting = false;
      });
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

  Future<void> _closeWindowById(int windowId) async {
    setState(() {
      _connectionStatus = 'Closing window ID: $windowId...';
    });

    try {
      // 닫기 전 윈도우가 존재하는지 확인
      final aliveResult = await _windowManager.isWindowAlive(windowId);
      if (!aliveResult.isSuccess && mounted) {
        ErrorUtils.showErrorDialog(context, '창 상태 확인 실패', aliveResult.error!);
        setState(() {
          _connectionStatus =
              'Error checking window status: ${aliveResult.error}';
        });
        return;
      }

      final closeResult = await _windowManager.closeWindow(windowId);

      if (closeResult.isSuccess && closeResult.data == true) {
        setState(() {
          _connectionStatus =
              'Window ID $windowId close command sent successfully';
        });

        // 창이 실제로 닫혔는지 확인
        await Future.delayed(const Duration(seconds: 2));
        final stillAliveResult = await _windowManager.isWindowAlive(windowId);

        if (stillAliveResult.isSuccess) {
          setState(() {
            _connectionStatus = (stillAliveResult.data == true)
                ? 'Window ID $windowId may still be open (check manually)'
                : 'Window ID $windowId successfully closed';
          });
        }
      } else {
        if (mounted && !closeResult.isSuccess) {
          ErrorUtils.showErrorDialog(context, '창 닫기 실패', closeResult.error!);
        }
        setState(() {
          _connectionStatus = closeResult.isSuccess
              ? 'Failed to close window ID $windowId - command returned false'
              : 'Failed to close window: ${closeResult.error}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error closing window: $e';
      });
    }
  }

  Future<void> _captureWindowById(int windowId) async {
    setState(() {
      _connectionStatus = 'Capturing window ID: $windowId...';
    });

    try {
      final result = await _windowManager.captureWindow(windowId);

      if (result.isSuccess && result.data != null) {
        final capturedImage = CapturedImage(
          windowId: windowId,
          imageData: result.data!,
          capturedAt: DateTime.now(),
        );

        setState(() {
          _capturedImages.add(capturedImage);
          _connectionStatus = 'Window ID $windowId captured successfully';
        });
      } else {
        if (mounted && !result.isSuccess) {
          ErrorUtils.showErrorDialog(context, '화면 캡처 실패', result.error!);
        }
        setState(() {
          _connectionStatus = result.isSuccess
              ? 'Failed to capture window ID $windowId'
              : 'Capture failed: ${result.error}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error capturing window: $e';
      });
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
            ConnectionForm(
              formKey: _formKey,
              serverController: _serverController,
              usernameController: _usernameController,
              passwordController: _passwordController,
              portController: _portController,
              isConnecting: _isConnecting,
              onConnect: _connectRDP,
            ),
            const SizedBox(height: 16),
            if (_connectionStatus.isNotEmpty)
              StatusMessage(message: _connectionStatus),
            const SizedBox(height: 16),
            if (_windowsAppPid != null)
              PidWindowsList(
                pid: _windowsAppPid!,
                rdpFilePath: _rdpFilePath,
                onCloseWindow: _closeWindowById,
                onCaptureWindow: _captureWindowById,
              ),
            if (_capturedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '캡처된 이미지 (${_capturedImages.length}개)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _capturedImages.length,
                          itemBuilder: (context, index) {
                            final image = _capturedImages[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        image.imageData,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Window ${image.windowId}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${image.capturedAt.hour}:${image.capturedAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
