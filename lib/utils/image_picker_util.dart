import 'dart:typed_data';

/// 이미지 선택 결과 (단일 이미지)
class PickedImage {
  final Uint8List bytes;
  final String fileName;
  const PickedImage(this.bytes, this.fileName);
}
