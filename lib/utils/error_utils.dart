import 'package:flutter/material.dart';
import '../services/window_manager_service.dart';

class ErrorUtils {
  /// 사용자 친화적인 에러 다이얼로그 표시
  static void showErrorDialog(BuildContext context, String title, WindowManagerError error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.message,
              style: const TextStyle(fontSize: 16),
            ),
            if (error.details != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error.details!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildSolutionWidget(error),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
          if (_requiresPermissionFix(error))
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openSystemPreferences();
              },
              child: const Text('설정 열기'),
            ),
        ],
      ),
    );
  }

  /// 에러 스낵바 표시
  static void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: '닫기',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 권한 관련 에러인지 확인
  static bool _requiresPermissionFix(WindowManagerError error) {
    return error.details?.contains('권한') == true ||
           error.details?.contains('permission') == true ||
           error.details?.contains('Permission') == true;
  }

  /// 해결책 위젯 생성
  static Widget _buildSolutionWidget(WindowManagerError error) {
    if (error.details?.contains('Screen Recording') == true) {
      return _buildPermissionSolution(
        '화면 기록 권한',
        'macOS 설정 > 개인정보 보호 및 보안 > 화면 및 시스템 오디오 기록에서 이 앱의 권한을 허용해주세요.',
        Icons.screen_share,
      );
    } else if (error.details?.contains('Accessibility') == true) {
      return _buildPermissionSolution(
        '접근성 권한',
        'macOS 설정 > 개인정보 보호 및 보안 > 접근성에서 이 앱의 권한을 허용해주세요.',
        Icons.accessibility,
      );
    } else if (error.details?.contains('창이 최소화') == true) {
      return _buildSolution(
        '창 복원',
        '창이 최소화되어 있습니다. 창을 복원한 후 다시 시도해주세요.',
        Icons.fullscreen_exit,
      );
    } else if (error.details?.contains('창을 찾을 수 없습니다') == true) {
      return _buildSolution(
        '창 상태 확인',
        '창이 이미 닫혔거나 숨겨진 상태일 수 있습니다. 연결 목록을 새로고침해주세요.',
        Icons.refresh,
      );
    }
    
    return _buildSolution(
      '일반적인 해결책',
      '앱을 다시 시작하거나 연결을 다시 시도해보세요.',
      Icons.restart_alt,
    );
  }

  static Widget _buildPermissionSolution(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  static Widget _buildSolution(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }

  /// 시스템 설정 열기
  static void _openSystemPreferences() {
    // Process.run을 사용해서 시스템 설정을 열 수 있지만
    // 여기서는 단순히 권한 설정에 대한 안내만 제공
  }
}