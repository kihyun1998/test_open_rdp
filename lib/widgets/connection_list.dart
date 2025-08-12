import 'package:flutter/material.dart';
import '../models/rdp_connection.dart';

class ConnectionList extends StatelessWidget {
  final List<RDPConnection> connections;
  final bool isRefreshing;
  final bool autoRefreshEnabled;
  final VoidCallback onRefreshAll;
  final VoidCallback onToggleAutoRefresh;
  final Function(int) onRefreshSingle;
  final Function(int) onCheckStatus;
  final Function(int) onCheckRDPConnection;
  final Function(int) onGetProcessDetails;
  final Function(RDPConnection) onKillConnection;

  const ConnectionList({
    super.key,
    required this.connections,
    required this.isRefreshing,
    required this.autoRefreshEnabled,
    required this.onRefreshAll,
    required this.onToggleAutoRefresh,
    required this.onRefreshSingle,
    required this.onCheckStatus,
    required this.onCheckRDPConnection,
    required this.onGetProcessDetails,
    required this.onKillConnection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Connections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.autorenew,
                      size: 16,
                      color: autoRefreshEnabled ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Auto',
                      style: TextStyle(
                        fontSize: 12,
                        color: autoRefreshEnabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    Switch(
                      value: autoRefreshEnabled,
                      onChanged: (value) => onToggleAutoRefresh(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isRefreshing ? null : onRefreshAll,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh All Connections',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${connections.length} active',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...connections.asMap().entries.map((entry) {
          final index = entry.key;
          final connection = entry.value;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.desktop_windows),
              title: Text('${connection.server}:${connection.port}'),
              subtitle: Text(
                'User: ${connection.username}\n'
                'Window ID: ${connection.windowId} | PID: ${connection.pid}\n'
                'Connected: ${connection.connectedAt.toString().substring(0, 19)}',
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: const Row(
                      children: [
                        Icon(Icons.refresh, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Refresh PID'),
                      ],
                    ),
                    onTap: () => onRefreshSingle(index),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: const Row(
                      children: [
                        Icon(Icons.info),
                        SizedBox(width: 8),
                        Text('Check Process'),
                      ],
                    ),
                    onTap: () => onCheckStatus(connection.windowId),
                  ),
                  PopupMenuItem(
                    value: 'rdp_check',
                    child: const Row(
                      children: [
                        Icon(Icons.network_check, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Check RDP Connection'),
                      ],
                    ),
                    onTap: () => onCheckRDPConnection(connection.windowId),
                  ),
                  PopupMenuItem(
                    value: 'details',
                    child: const Row(
                      children: [
                        Icon(Icons.description, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Process Details'),
                      ],
                    ),
                    onTap: () => onGetProcessDetails(connection.windowId),
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
                    onTap: () => onKillConnection(connection),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }
}