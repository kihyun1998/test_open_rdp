import 'rdp_connection.dart';

enum ConnectionResultType {
  success,           // 새 창이 생성됨
  existingFocused,   // 기존 창이 포커싱됨
  appError,          // Windows App 내부 오류
  commandFailed,     // open 명령어 실패
  appNotFound,       // Windows App이 설치되지 않음
}

class ConnectionResult {
  final ConnectionResultType type;
  final RDPConnection? connection;
  final String message;
  final String? error;

  ConnectionResult({
    required this.type,
    this.connection,
    required this.message,
    this.error,
  });

  bool get isSuccess => type == ConnectionResultType.success;
  bool get isExistingFocused => type == ConnectionResultType.existingFocused;
  bool get isAppError => type == ConnectionResultType.appError;
  bool get isFailed => type == ConnectionResultType.commandFailed;
  bool get isAppNotFound => type == ConnectionResultType.appNotFound;
}