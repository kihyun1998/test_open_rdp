class RDPConnection {
  final String server;
  final String username;
  final String port;
  final int windowId;
  final int pid; // 참고용으로 유지
  final String rdpFilePath;
  final DateTime connectedAt;

  RDPConnection({
    required this.server,
    required this.username,
    required this.port,
    required this.windowId,
    required this.pid,
    required this.rdpFilePath,
    required this.connectedAt,
  });

  @override
  String toString() {
    return 'RDPConnection(server: $server, windowId: $windowId, pid: $pid)';
  }
}