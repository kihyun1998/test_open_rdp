import 'dart:typed_data';

class CapturedImage {
  final int windowId;
  final Uint8List imageData;
  final DateTime capturedAt;

  CapturedImage({
    required this.windowId,
    required this.imageData,
    required this.capturedAt,
  });
}
