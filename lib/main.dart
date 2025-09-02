import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models/rdp_connection.dart';
import 'models/connection_result.dart';
import 'services/rdp_service.dart';
import 'services/window_manager_service.dart';
import 'utils/error_utils.dart';
import 'widgets/connection_form.dart';
import 'widgets/connection_list.dart';
import 'widgets/pid_windows_list.dart';
import 'widgets/status_message.dart';

class CapturedImage {
  final int windowId;
  final Uint8List imageData;
  final DateTime capturedAt;

  CapturedImage({
    required this.windowId,
    required this.imageData,
    required this.capturedAt,
  });
}

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
  final _serverController = TextEditingController(text: "192.168.136.134");
  final _usernameController = TextEditingController(text: "Administrator");
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '3389');
  final _rdpService = RDPService();
  final _windowManager = WindowManagerService();

  bool _isConnecting = false;
  bool _isRefreshing = false;
  bool _autoRefreshEnabled = false;
  String _connectionStatus = '';
  List<RDPConnection> _activeConnections = [];
  Timer? _autoRefreshTimer;
  final List<CapturedImage> _capturedImages = [];

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });

    if (_autoRefreshEnabled) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (mounted && _activeConnections.isNotEmpty) {
          _refreshAllConnections();
        }
      });
      setState(() {
        _connectionStatus = 'Auto-refresh enabled (every 30 seconds)';
      });
    } else {
      _autoRefreshTimer?.cancel();
      setState(() {
        _connectionStatus = 'Auto-refresh disabled';
      });
    }
  }

  Future<void> _connectRDP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
    });

    final result = await _rdpService.connectRDP(
      server: _serverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      port: _portController.text,
      onStatusUpdate: (status) {
        if (mounted) {
          setState(() {
            _connectionStatus = status;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isConnecting = false;
        
        // 결과에 따른 상태 업데이트
        switch (result.type) {
          case ConnectionResultType.success:
            if (result.connection != null) {
              _activeConnections.add(result.connection!);
            }
            _connectionStatus = '✅ ${result.message}';
            break;
          case ConnectionResultType.existingFocused:
            _connectionStatus = '🔄 ${result.message}';
            break;
          case ConnectionResultType.appError:
            _connectionStatus = '⚠️ ${result.message}';
            if (result.error != null) {
              _connectionStatus += '\nError: ${result.error}';
            }
            break;
          case ConnectionResultType.commandFailed:
            _connectionStatus = '❌ ${result.message}';
            if (result.error != null) {
              _connectionStatus += '\nError: ${result.error}';
            }
            break;
          case ConnectionResultType.appNotFound:
            _connectionStatus = '🚫 ${result.message}';
            if (result.error != null) {
              _connectionStatus += '\n${result.error}';
            }
            break;
        }
      });
    }
  }

  Future<void> _killConnection(RDPConnection connection) async {
    try {
      await _rdpService.killConnection(connection);
      setState(() {
        _activeConnections.remove(connection);
        _connectionStatus = 'Connection terminated (PID: ${connection.pid})';
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error terminating connection: $e';
      });
    }
  }

  Future<void> _refreshAllConnections() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _connectionStatus = 'Refreshing all connections...';
    });

    try {
      final List<RDPConnection> updatedConnections = [];

      for (final connection in _activeConnections) {
        final result = await _windowManager.isWindowAlive(connection.windowId);

        if (result.isSuccess && result.data == true) {
          updatedConnections.add(connection);
        } else if (!result.isSuccess) {
          print('Warning: ${result.error}');
        }
        // Window가 사라진 경우 또는 오류 시 연결 목록에서 제거
      }

      setState(() {
        _activeConnections = updatedConnections;
        _connectionStatus =
            'Refresh completed. Found ${updatedConnections.length} active connections.';
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = 'Refresh failed: $e';
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSingleConnection(int index) async {
    if (index >= _activeConnections.length) return;

    final connection = _activeConnections[index];
    setState(() {
      _connectionStatus = 'Refreshing connection to ${connection.server}...';
    });

    try {
      final result = await _windowManager.isWindowAlive(connection.windowId);

      if (result.isSuccess) {
        if (result.data == true) {
          setState(() {
            _connectionStatus =
                'Connection to ${connection.server} (Window ID: ${connection.windowId}) is active';
          });
        } else {
          setState(() {
            _activeConnections.removeAt(index);
            _connectionStatus =
                'Connection to ${connection.server} removed (window closed)';
          });
        }
      } else {
        setState(() {
          _connectionStatus = 'Failed to refresh connection: ${result.error}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to refresh connection: $e';
      });
    }
  }

  Future<void> _closeWindowById(int windowId) async {
    print('🔄 Main: Attempting to close window ID: $windowId');
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
      print(
        '🔄 Main: Window $windowId is alive before close: ${aliveResult.data}',
      );

      final closeResult = await _windowManager.closeWindow(windowId);
      print('🔄 Main: Close operation result: ${closeResult.isSuccess}');

      if (closeResult.isSuccess && closeResult.data == true) {
        setState(() {
          _connectionStatus =
              'Window ID $windowId close command sent successfully';
        });

        // 창이 실제로 닫혔는지 확인
        await Future.delayed(const Duration(seconds: 2));
        final stillAliveResult = await _windowManager.isWindowAlive(windowId);

        if (stillAliveResult.isSuccess) {
          print(
            '🔄 Main: Window $windowId is alive after close: ${stillAliveResult.data}',
          );
          setState(() {
            _connectionStatus = (stillAliveResult.data == true)
                ? 'Window ID $windowId may still be open (check manually)'
                : 'Window ID $windowId successfully closed';
          });
        }

        // 연결 목록 새로고침
        await _refreshAllConnections();
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
      print('❌ Main: Error closing window: $e');
      setState(() {
        _connectionStatus = 'Error closing window: $e';
      });
    }
  }

  Future<void> _captureWindowById(int windowId) async {
    print('📷 Main: Capturing window ID: $windowId');
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
      print('❌ Main: Error capturing window: $e');
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
            if (_activeConnections.isNotEmpty) ...[
              ConnectionList(
                connections: _activeConnections,
                isRefreshing: _isRefreshing,
                autoRefreshEnabled: _autoRefreshEnabled,
                onRefreshAll: _refreshAllConnections,
                onToggleAutoRefresh: _toggleAutoRefresh,
                onRefreshSingle: _refreshSingleConnection,
                onCheckStatus: (windowId) async {
                  final connection = _activeConnections.firstWhere(
                    (c) => c.windowId == windowId,
                  );
                  final result = await _windowManager.isWindowAlive(
                    connection.windowId,
                  );
                  if (mounted) {
                    setState(() {
                      if (result.isSuccess) {
                        _connectionStatus = (result.data == true)
                            ? 'Window ID $windowId is active'
                            : 'Window ID $windowId is not active';
                      } else {
                        ErrorUtils.showErrorSnackBar(
                          context,
                          '창 상태 확인 실패: ${result.error?.message}',
                        );
                        _connectionStatus =
                            'Error checking status: ${result.error}';
                      }
                    });
                  }
                },
                onCheckRDPConnection: (windowId) async {
                  final connection = _activeConnections.firstWhere(
                    (c) => c.windowId == windowId,
                  );
                  setState(() {
                    _connectionStatus =
                        'Checking RDP connection for Window ID $windowId...';
                  });
                  final isRDPConnected = await _rdpService.isRDPConnection(
                    connection.pid,
                  );
                  if (mounted) {
                    setState(() {
                      _connectionStatus = isRDPConnected
                          ? 'Window ID $windowId has active RDP connection'
                          : 'Window ID $windowId has no active RDP connection';
                    });
                  }
                },
                onGetProcessDetails: (windowId) async {
                  final connection = _activeConnections.firstWhere(
                    (c) => c.windowId == windowId,
                  );
                  setState(() {
                    _connectionStatus =
                        'Getting details for Window ID $windowId...';
                  });
                  final details = await _rdpService.getProcessDetails(
                    connection.pid,
                  );
                  if (mounted) {
                    setState(() {
                      _connectionStatus =
                          'Window ID $windowId details:\n$details';
                    });
                  }
                },
                onKillConnection: _killConnection,
              ),
              const SizedBox(height: 16),
              // PID의 모든 창들 표시
              ...(_activeConnections
                  .map((connection) => connection.pid)
                  .toSet()
                  .map(
                    (pid) => PidWindowsList(
                      pid: pid,
                      onCloseWindow: _closeWindowById,
                      onCaptureWindow: _captureWindowById,
                    ),
                  )),
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
          ],
        ),
      ),
      floatingActionButton: _activeConnections.isNotEmpty
          ? FloatingActionButton(
              onPressed: _isRefreshing ? null : _refreshAllConnections,
              tooltip: 'Quick Refresh All',
              backgroundColor: _isRefreshing ? Colors.grey : Colors.blue,
              child: _isRefreshing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.refresh),
            )
          : null,
    );
  }
}
