import 'dart:async';

import 'package:flutter/material.dart';

import 'models/rdp_connection.dart';
import 'services/rdp_service.dart';
import 'widgets/connection_form.dart';
import 'widgets/connection_list.dart';
import 'widgets/status_message.dart';

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
  final _rdpService = RDPService();

  bool _isConnecting = false;
  bool _isRefreshing = false;
  bool _autoRefreshEnabled = false;
  String _connectionStatus = '';
  List<RDPConnection> _activeConnections = [];
  Timer? _autoRefreshTimer;

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

  Future<RDPConnection?> _connectRDP() async {
    if (!_formKey.currentState!.validate()) return null;

    setState(() {
      _isConnecting = true;
    });

    final connection = await _rdpService.connectRDP(
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
        if (connection != null) {
          _activeConnections.add(connection);
        }
      });
    }

    return connection;
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
      final allPids = await _rdpService.getAllWindowsAppPids();
      final List<RDPConnection> updatedConnections = [];

      for (final connection in _activeConnections) {
        final isAlive = await _rdpService.isProcessAlive(connection.pid);

        if (isAlive) {
          updatedConnections.add(connection);
        } else {
          final newConnection = await _findNewPidForConnection(
            connection,
            allPids,
          );
          if (newConnection != null) {
            updatedConnections.add(newConnection);
          }
        }
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

  Future<RDPConnection?> _findNewPidForConnection(
    RDPConnection oldConnection,
    List<int> availablePids,
  ) async {
    // 사용되지 않은 PID 중에서 새로운 PID 찾기
    final usedPids = _activeConnections.map((c) => c.pid).toSet();
    final unusedPids = availablePids
        .where((pid) => !usedPids.contains(pid))
        .toList();

    if (unusedPids.isNotEmpty) {
      // 가장 최근 PID를 새로운 PID로 사용
      final newPid = unusedPids.last;
      return RDPConnection(
        server: oldConnection.server,
        username: oldConnection.username,
        port: oldConnection.port,
        pid: newPid,
        rdpFilePath: oldConnection.rdpFilePath,
        connectedAt: oldConnection.connectedAt,
      );
    }

    return null;
  }

  Future<void> _refreshSingleConnection(int index) async {
    if (index >= _activeConnections.length) return;

    final connection = _activeConnections[index];
    setState(() {
      _connectionStatus = 'Refreshing connection to ${connection.server}...';
    });

    try {
      final isAlive = await _rdpService.isProcessAlive(connection.pid);

      if (isAlive) {
        setState(() {
          _connectionStatus =
              'Connection to ${connection.server} (PID: ${connection.pid}) is active';
        });
        return;
      }

      final allPids = await _rdpService.getAllWindowsAppPids();
      final usedPids = _activeConnections.map((c) => c.pid).toSet();
      final unusedPids = allPids
          .where((pid) => !usedPids.contains(pid))
          .toList();

      if (unusedPids.isNotEmpty) {
        final newPid = unusedPids.last;
        final updatedConnection = RDPConnection(
          server: connection.server,
          username: connection.username,
          port: connection.port,
          pid: newPid,
          rdpFilePath: connection.rdpFilePath,
          connectedAt: connection.connectedAt,
        );

        setState(() {
          _activeConnections[index] = updatedConnection;
          _connectionStatus =
              'Connection to ${connection.server} updated with new PID: $newPid';
        });
      } else {
        setState(() {
          _activeConnections.removeAt(index);
          _connectionStatus =
              'Connection to ${connection.server} removed (no active process found)';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to refresh connection: $e';
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
            if (_activeConnections.isNotEmpty)
              ConnectionList(
                connections: _activeConnections,
                isRefreshing: _isRefreshing,
                autoRefreshEnabled: _autoRefreshEnabled,
                onRefreshAll: _refreshAllConnections,
                onToggleAutoRefresh: _toggleAutoRefresh,
                onRefreshSingle: _refreshSingleConnection,
                onCheckStatus: (pid) async {
                  final isAlive = await _rdpService.isProcessAlive(pid);
                  if (mounted) {
                    setState(() {
                      _connectionStatus = isAlive
                          ? 'Process $pid is running'
                          : 'Process $pid is not running';
                    });
                  }
                },
                onKillConnection: _killConnection,
              ),
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
