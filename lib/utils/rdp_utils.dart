/// Utility functions for RDP file and connection management
class RdpUtils {
  /// Extracts the RDP filename without extension from a full file path
  ///
  /// Example:
  /// - Input: "/var/folders/.../connection_1729123456789.rdp"
  /// - Output: "connection_1729123456789"
  static String extractRdpFileName(String filePath) {
    if (filePath.isEmpty) return '';

    // Get the filename from the full path
    final fileName = filePath.split('/').last;

    // Remove the .rdp extension
    if (fileName.endsWith('.rdp')) {
      return fileName.substring(0, fileName.length - 4);
    }

    return fileName;
  }

  /// Checks if a window name matches any of the given RDP file names
  ///
  /// Performs case-insensitive matching
  static bool isMatchingRdpWindow(String windowName, List<String> rdpFileNames) {
    if (windowName.isEmpty || rdpFileNames.isEmpty) return false;

    final lowerWindowName = windowName.toLowerCase();

    return rdpFileNames.any((rdpFileName) =>
      lowerWindowName.contains(rdpFileName.toLowerCase())
    );
  }

  /// Extracts RDP file names from a list of file paths
  ///
  /// Example:
  /// - Input: ["/path/connection_123.rdp", "/path/connection_456.rdp"]
  /// - Output: ["connection_123", "connection_456"]
  static List<String> extractRdpFileNames(List<String> filePaths) {
    return filePaths
        .map((path) => extractRdpFileName(path))
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
