import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// 네이티브(Android/iOS) 환경에서 PDF 파일 선택 및 바이트 읽기
Future<(Uint8List, String)?> pickPdfFile() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;
    return (bytes, file.name);
  } catch (_) {
    return null;
  }
}
