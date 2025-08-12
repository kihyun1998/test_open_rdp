import 'package:flutter/material.dart';
import '../services/window_manager_service.dart';

class PidWindowsList extends StatefulWidget {
  final int pid;
  final Function(int) onCloseWindow;
  final Function(int) onCaptureWindow;

  const PidWindowsList({
    super.key,
    required this.pid,
    required this.onCloseWindow,
    required this.onCaptureWindow,
  });

  @override
  State<PidWindowsList> createState() => _PidWindowsListState();
}

class _PidWindowsListState extends State<PidWindowsList> {
  List<WindowInfo> _windows = [];
  List<WindowInfo> _previousWindows = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdate;
  final WindowManagerService _windowManager = WindowManagerService();

  @override
  void initState() {
    super.initState();
    _refreshWindows();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PID ${widget.pid}의 모든 창들',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_lastUpdate != null)
              Text(
                '마지막 업데이트: ${_formatTime(_lastUpdate!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        Row(
          children: [
            if (_windows.isNotEmpty)
              Text(
                '${_windows.length}개 창',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoading ? null : _refreshWindows,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: '새로고침',
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading && _windows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Error: $_error',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (_windows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            const Text('이 PID에 해당하는 창이 없습니다.'),
          ],
        ),
      );
    }

    return Column(
      children: _windows.map((window) => _buildWindowCard(window)).toList(),
    );
  }

  Future<void> _refreshWindows() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _previousWindows = List.from(_windows);
      
      final allWindows = await _windowManager.getWindowsAppWindows();
      final pidWindows = allWindows.where((window) => window.ownerPID == widget.pid).toList();
      
      // 변화 감지
      final previousIds = _previousWindows.map((w) => w.windowId).toSet();
      final currentIds = pidWindows.map((w) => w.windowId).toSet();
      
      final newWindows = currentIds.difference(previousIds);
      final removedWindows = previousIds.difference(currentIds);
      
      if (newWindows.isNotEmpty) {
        print('🆕 New windows: ${newWindows.toList()}');
      }
      if (removedWindows.isNotEmpty) {
        print('❌ Removed windows: ${removedWindows.toList()}');
      }

      setState(() {
        _windows = pidWindows;
        _lastUpdate = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error refreshing windows: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Widget _buildWindowCard(WindowInfo window) {
    final isNew = _isNewWindow(window.windowId);
    final wasRemoved = _wasWindowRemoved(window.windowId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isNew ? 4 : 2,
      color: isNew ? Colors.green.shade50 : null,
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.window,
              color: _getWindowColor(window),
            ),
            if (isNew) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.fiber_new,
                color: Colors.green.shade700,
                size: 16,
              ),
            ],
          ],
        ),
        title: Text('Window ID: ${window.windowId}'),
        subtitle: Text(
          'Size: ${window.width.toInt()}x${window.height.toInt()}\n'
          'Position: (${window.x.toInt()}, ${window.y.toInt()})\n'
          'Name: "${window.windowName.isEmpty ? "No Name" : window.windowName}"',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_getWindowPriority(window) == 'Main')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MAIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.green),
              onPressed: () => _captureWindow(window.windowId),
              tooltip: '창 캡처',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => _closeWindow(window.windowId),
              tooltip: '이 창 닫기',
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _closeWindow(int windowId) async {
    print('🔄 Attempting to close window ID: $windowId');
    widget.onCloseWindow(windowId);
    // 창 닫기 후 잠시 대기하고 새로고침
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _refreshWindows();
      }
    });
  }

  Future<void> _captureWindow(int windowId) async {
    print('📷 Capturing window ID: $windowId');
    widget.onCaptureWindow(windowId);
  }

  bool _isNewWindow(int windowId) {
    if (_previousWindows.isEmpty) return false;
    return !_previousWindows.any((w) => w.windowId == windowId);
  }

  bool _wasWindowRemoved(int windowId) {
    if (_previousWindows.isEmpty) return false;
    return _previousWindows.any((w) => w.windowId == windowId) && 
           !_windows.any((w) => w.windowId == windowId);
  }

  String _getWindowPriority(WindowInfo window) {
    final area = window.width * window.height;
    if (area > 500000) return 'Main';
    if (area > 100000) return 'Dialog';
    return 'UI';
  }

  Color _getWindowColor(WindowInfo window) {
    final area = window.width * window.height;
    if (area > 500000) return Colors.blue; // 큰 창 (메인 RDP)
    if (area > 100000) return Colors.orange; // 중간 창 (다이얼로그)
    return Colors.grey; // 작은 창 (UI 요소)
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }
}