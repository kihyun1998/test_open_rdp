class RDPConnection {
  final String server;
  final String username;
  final String port;
  final int pid;
  final String rdpFilePath;
  final DateTime connectedAt;

  RDPConnection({
    required this.server,
    required this.username,
    required this.port,
    required this.pid,
    required this.rdpFilePath,
    required this.connectedAt,
  });

  @override
  String toString() {
    return 'RDPConnection(server: $server, pid: $pid)';
  }
}