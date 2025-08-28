import 'dart:io';

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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_lastUpdate != null)
              Text(
                '마지막 업데이트: ${_formatTime(_lastUpdate!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        Row(
          children: [
            if (_windows.isNotEmpty)
              Text(
                '${_windows.length}개 창',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'terminate') {
                  _terminateProcess();
                } else if (value == 'force_quit') {
                  _forceQuitProcess();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'terminate',
                  child: Row(
                    children: [
                      Icon(Icons.stop, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('정상 종료 (TERM)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'force_quit',
                  child: Row(
                    children: [
                      Icon(Icons.power_settings_new, color: Colors.red),
                      SizedBox(width: 8),
                      Text('강제 종료 (KILL)'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
              tooltip: '프로세스 종료 옵션',
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (value) {
                _closeWindowsByName(value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'Devices',
                  child: Row(
                    children: [
                      Icon(Icons.devices, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('"Devices" 창 닫기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'login',
                  child: Row(
                    children: [
                      Icon(Icons.login, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('"login" 창 닫기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'dialog',
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('"dialog" 창 닫기'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'error',
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Text('"error" 창 닫기'),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.filter_list),
              tooltip: '특정 이름의 창 닫기',
              iconColor: Colors.purple.shade700,
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isLoading ? null : _closeAllNonRdpWindows,
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'RDP 연결창 제외하고 모두 닫기',
              style: IconButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
                foregroundColor: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 4),
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

      final result = await _windowManager.getWindowsAppWindows();

      if (result.isSuccess && result.data != null) {
        final pidWindows = result.data!
            .where((window) => window.ownerPID == widget.pid)
            .toList();

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
      } else {
        setState(() {
          _error = result.error?.toString() ?? 'Unknown error occurred';
          _isLoading = false;
        });
      }
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
    final isRdpConnection = _isRdpConnectionWindow(window);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isNew ? 4 : 2,
      color: isNew
          ? Colors.green.shade50
          : (isRdpConnection ? Colors.blue.shade50 : null),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.window, color: _getWindowColor(window)),
            if (isRdpConnection) ...[
              const SizedBox(width: 4),
              Icon(Icons.shield, color: Colors.blue.shade700, size: 16),
            ],
            if (isNew) ...[
              const SizedBox(width: 4),
              Icon(Icons.fiber_new, color: Colors.green.shade700, size: 16),
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
            if (isRdpConnection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RDP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            if (_getWindowPriority(window) == 'Main' && !isRdpConnection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'MAIN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.blue),
              onPressed: () => _showWindowDetails(window),
              tooltip: '창 상세 정보',
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.green),
              onPressed: () => _captureWindow(window.windowId),
              tooltip: '창 캡처',
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: isRdpConnection ? Colors.grey : Colors.red,
              ),
              onPressed: isRdpConnection
                  ? null
                  : () => _closeWindow(window.windowId),
              tooltip: isRdpConnection ? 'RDP 연결창은 보호됩니다' : '이 창 닫기',
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

  void _showWindowDetails(WindowInfo window) {
    showDialog(
      context: context,
      builder: (BuildContext context) => _buildWindowDetailsDialog(window),
    );
  }

  Widget _buildWindowDetailsDialog(WindowInfo window) {
    final area = window.width * window.height;
    final priority = _getWindowPriority(window);
    final aspectRatio = window.height != 0 ? window.width / window.height : 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.window, color: _getWindowColor(window), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '창 상세 정보',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Window ID: ${window.windowId}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (priority == 'Main')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'MAIN WINDOW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      '창 이름',
                      window.windowName.isEmpty ? '(이름 없음)' : window.windowName,
                    ),
                    _buildDetailRow('소유 앱', window.ownerName),
                    _buildDetailRow('소유 프로세스 ID', '${window.ownerPID}'),
                    const Divider(height: 24),
                    Text(
                      '위치 및 크기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      '위치 (X, Y)',
                      '(${window.x.toInt()}, ${window.y.toInt()})',
                    ),
                    _buildDetailRow(
                      '크기 (가로 x 세로)',
                      '${window.width.toInt()} x ${window.height.toInt()} px',
                    ),
                    _buildDetailRow(
                      '화면 영역',
                      '${area.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (match) => '${match[1]},')} px²',
                    ),
                    _buildDetailRow(
                      '가로세로 비율',
                      aspectRatio > 0
                          ? '${aspectRatio.toStringAsFixed(2)}:1'
                          : 'N/A',
                    ),
                    const Divider(height: 24),
                    Text(
                      '창 상태',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      '화면 표시',
                      window.isOnScreen ? '✅ 화면에 표시됨' : '❌ 화면에 숨겨짐',
                    ),
                    _buildDetailRow(
                      '투명도',
                      '${(window.alpha * 100).toInt()}% (${window.alpha.toStringAsFixed(2)})',
                    ),
                    _buildDetailRow('레이어 레벨', '${window.layer}'),
                    _buildDetailRow(
                      '공유 상태',
                      _getSharingStateDescription(window.sharingState),
                    ),
                    const Divider(height: 24),
                    Text(
                      '시스템 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      '메모리 사용량',
                      _formatMemoryUsage(window.memoryUsage),
                    ),
                    _buildDetailRow(
                      '비디오 메모리',
                      window.isInVideoMemory ? '✅ VRAM 사용' : '📝 RAM 사용',
                    ),
                    _buildDetailRow('저장소 타입', '${window.storeType}'),
                    const Divider(height: 24),
                    Text(
                      '분석 정보',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('창 우선순위', priority),
                    _buildDetailRow('창 유형', _getWindowTypeDescription(area)),
                    if (_isNewWindow(window.windowId)) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.fiber_new,
                              color: Colors.green.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '새로 생성된 창입니다',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _captureWindow(window.windowId);
                  },
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: const Text('캡처'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _closeWindow(window.windowId);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('창 닫기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  String _getWindowTypeDescription(double area) {
    if (area > 500000) return '메인 창 (대형)';
    if (area > 100000) return '다이얼로그 창 (중형)';
    return 'UI 요소 창 (소형)';
  }

  String _getSharingStateDescription(int sharingState) {
    switch (sharingState) {
      case 0:
        return '🚫 공유 없음 (None)';
      case 1:
        return '👁️ 읽기 전용 (ReadOnly)';
      case 2:
        return '✏️ 읽기/쓰기 (ReadWrite)';
      default:
        return '❓ 알 수 없음 ($sharingState)';
    }
  }

  String _formatMemoryUsage(int bytes) {
    if (bytes == 0) return '정보 없음';
    if (bytes < 1024) return '$bytes bytes';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool _isRdpConnectionWindow(WindowInfo window) {
    return window.windowName.startsWith('connection_') &&
        window.windowName.contains(RegExp(r'connection_\d+'));
  }

  Future<void> _closeAllNonRdpWindows() async {
    final nonRdpWindows = _windows
        .where((window) => !_isRdpConnectionWindow(window))
        .toList();

    if (nonRdpWindows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('닫을 창이 없습니다. 모든 창이 RDP 연결창입니다.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('창 정리 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다음 ${nonRdpWindows.length}개의 창을 닫으시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: nonRdpWindows
                      .map(
                        (window) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${window.windowName.isEmpty ? "이름 없음" : window.windowName} (ID: ${window.windowId})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '🛡️ RDP 연결창은 보호되어 닫히지 않습니다.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('정리하기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('🧹 Starting cleanup of ${nonRdpWindows.length} non-RDP windows');
      int closedCount = 0;

      for (final window in nonRdpWindows) {
        print(
          '🧹 Closing window: ${window.windowName} (ID: ${window.windowId})',
        );
        widget.onCloseWindow(window.windowId);
        closedCount++;

        // 창 닫기 사이에 약간의 지연을 추가
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$closedCount개의 창을 정리했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // 정리 후 창 목록 새로고침
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _refreshWindows();
        }
      });
    }
  }

  Future<void> _closeWindowsByName(String namePattern) async {
    final matchingWindows = _windows
        .where(
          (window) => window.windowName.toLowerCase().contains(
            namePattern.toLowerCase(),
          ),
        )
        .toList();

    if (matchingWindows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$namePattern" 창을 찾을 수 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 아이콘과 색상 설정
    IconData dialogIcon;
    MaterialColor dialogColor;
    String description;

    switch (namePattern.toLowerCase()) {
      case 'Devices':
        dialogIcon = Icons.devices;
        dialogColor = Colors.purple;
        description = '📱 보통 디바이스 연결 창이나 USB 리디렉션 창입니다.';
        break;
      case 'login':
        dialogIcon = Icons.login;
        dialogColor = Colors.blue;
        description = '🔐 로그인 창이나 인증 창입니다.';
        break;
      case 'dialog':
        dialogIcon = Icons.chat_bubble;
        dialogColor = Colors.orange;
        description = '💬 다양한 대화상자나 알림창입니다.';
        break;
      case 'error':
        dialogIcon = Icons.error;
        dialogColor = Colors.red;
        description = '❌ 오류 메시지나 경고창입니다.';
        break;
      default:
        dialogIcon = Icons.window;
        dialogColor = Colors.grey;
        description = '🪟 선택한 이름 패턴과 일치하는 창들입니다.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(dialogIcon, color: dialogColor.shade700),
            const SizedBox(width: 8),
            Text('$namePattern 창 닫기'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다음 ${matchingWindows.length}개의 "$namePattern" 창을 닫으시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: matchingWindows
                      .map(
                        (window) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${window.windowName.isEmpty ? "(이름 없음)" : window.windowName} (ID: ${window.windowId})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dialogColor.shade50,
                border: Border.all(color: dialogColor.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dialogColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('닫기'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      print('🎯 Closing ${matchingWindows.length} "$namePattern" windows');
      int closedCount = 0;

      for (final window in matchingWindows) {
        print(
          '🎯 Closing "$namePattern" window: ${window.windowName} (ID: ${window.windowId})',
        );
        widget.onCloseWindow(window.windowId);
        closedCount++;

        // 창 닫기 사이에 약간의 지연을 추가
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$closedCount개의 "$namePattern" 창을 닫았습니다.'),
            backgroundColor: dialogColor,
          ),
        );
      }

      // 정리 후 창 목록 새로고침
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _refreshWindows();
        }
      });
    }
  }

  Future<void> _terminateProcess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.stop, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('프로세스 정상 종료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PID ${widget.pid} 프로세스를 정상 종료하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '정상 종료 신호(SIGTERM)를 보내 앱이 깔끔하게 종료되도록 합니다.\n'
                '시스템 트레이에서도 제거됩니다.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'kill -TERM ${widget.pid} 명령어를 실행합니다.',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('정상 종료'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('🛑 Terminating process PID: ${widget.pid}');

        // kill -TERM 명령어로 프로세스 정상 종료
        final result = await Process.run('kill', ['-TERM', '${widget.pid}']);

        if (result.exitCode == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PID ${widget.pid} 프로세스 종료 신호를 보냈습니다.'),
                backgroundColor: Colors.orange,
              ),
            );
          }

          // 프로세스 종료 후 창 목록 새로고침
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) {
              _refreshWindows();
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('프로세스 종료 실패: ${result.stderr}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Error terminating process: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프로세스 종료 중 오류: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _forceQuitProcess() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('프로세스 강제 종료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PID ${widget.pid} 프로세스를 강제로 종료하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 경고',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• 시스템 트레이에 숨어있는 프로세스도 완전히 종료됩니다\n'
                    '• 저장하지 않은 데이터가 손실될 수 있습니다\n'
                    '• RDP 연결이 강제로 끊어집니다',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'kill -9 ${widget.pid} 명령어를 실행합니다.',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('강제 종료'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        print('💀 Force quitting process PID: ${widget.pid}');

        // kill -9 명령어로 프로세스 강제 종료
        final result = await Process.run('kill', ['-9', '${widget.pid}']);

        if (result.exitCode == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PID ${widget.pid} 프로세스가 강제 종료되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }

          // 프로세스 종료 후 창 목록 새로고침
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              _refreshWindows();
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('프로세스 종료 실패: ${result.stderr}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Error force quitting process: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('프로세스 종료 중 오류: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  bool _isNewWindow(int windowId) {
    if (_previousWindows.isEmpty) return false;
    return !_previousWindows.any((w) => w.windowId == windowId);
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
