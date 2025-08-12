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
      final List<RDPConnection> updatedConnections = [];

      for (final connection in _activeConnections) {
        final isAlive = await _rdpService.isWindowAlive(connection.windowId);

        if (isAlive) {
          updatedConnections.add(connection);
        }
        // Window가 사라진 경우 연결 목록에서 제거
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
      final isAlive = await _rdpService.isWindowAlive(connection.windowId);

      if (isAlive) {
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
                onCheckStatus: (windowId) async {
                  final connection = _activeConnections.firstWhere((c) => c.windowId == windowId);
                  final isAlive = await _rdpService.isWindowAlive(connection.windowId);
                  if (mounted) {
                    setState(() {
                      _connectionStatus = isAlive
                          ? 'Window ID $windowId is active'
                          : 'Window ID $windowId is not active';
                    });
                  }
                },
                onCheckRDPConnection: (windowId) async {
                  final connection = _activeConnections.firstWhere((c) => c.windowId == windowId);
                  setState(() {
                    _connectionStatus = 'Checking RDP connection for Window ID $windowId...';
                  });
                  final isRDPConnected = await _rdpService.isRDPConnection(connection.pid);
                  if (mounted) {
                    setState(() {
                      _connectionStatus = isRDPConnected
                          ? 'Window ID $windowId has active RDP connection'
                          : 'Window ID $windowId has no active RDP connection';
                    });
                  }
                },
                onGetProcessDetails: (windowId) async {
                  final connection = _activeConnections.firstWhere((c) => c.windowId == windowId);
                  setState(() {
                    _connectionStatus = 'Getting details for Window ID $windowId...';
                  });
                  final details = await _rdpService.getProcessDetails(connection.pid);
                  if (mounted) {
                    setState(() {
                      _connectionStatus = 'Window ID $windowId details:\n$details';
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
