import 'package:flutter/material.dart';
import '../services/window_manager_service.dart';

class PidWindowsList extends StatelessWidget {
  final int pid;
  final Function(int) onCloseWindow;

  const PidWindowsList({
    super.key,
    required this.pid,
    required this.onCloseWindow,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PID $pid의 모든 창들',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<WindowInfo>>(
              future: _getWindowsForPid(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                
                final windows = snapshot.data ?? [];
                
                if (windows.isEmpty) {
                  return const Text('이 PID에 해당하는 창이 없습니다.');
                }
                
                return Column(
                  children: windows.map((window) => _buildWindowCard(window)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<WindowInfo>> _getWindowsForPid() async {
    final windowManager = WindowManagerService();
    final allWindows = await windowManager.getWindowsAppWindows();
    return allWindows.where((window) => window.ownerPID == pid).toList();
  }

  Widget _buildWindowCard(WindowInfo window) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.window,
          color: _getWindowColor(window),
        ),
        title: Text('Window ID: ${window.windowId}'),
        subtitle: Text(
          'Size: ${window.width.toInt()}x${window.height.toInt()}\n'
          'Position: (${window.x.toInt()}, ${window.y.toInt()})\n'
          'Name: "${window.windowName.isEmpty ? "No Name" : window.windowName}"',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => onCloseWindow(window.windowId),
          tooltip: '이 창 닫기',
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getWindowColor(WindowInfo window) {
    final area = window.width * window.height;
    if (area > 500000) return Colors.blue; // 큰 창 (메인 RDP)
    if (area > 100000) return Colors.orange; // 중간 창 (다이얼로그)
    return Colors.grey; // 작은 창 (UI 요소)
  }
}