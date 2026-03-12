// PDF 파일 선택 유틸리티 (웹 전용)
// 설계 원칙: onTap → openPicker() → 즉시 동기 click()
//           파일 선택 완료 → onSuccess 콜백
// async/await 체인 완전 제거 → 브라우저 이벤트 컨텍스트 유지
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// 웹에서 PDF 파일 선택을 관리하는 클래스
/// initState()에서 생성, dispose()에서 해제
class PdfFilePicker {
  html.FileUploadInputElement? _input;
  void Function(Uint8List bytes, String name)? _onSuccess;
  void Function()? _onCancel;

  PdfFilePicker() {
    _input = html.FileUploadInputElement()
      ..accept = '.pdf,application/pdf'
      ..style.cssText =
          'position:fixed;top:-500px;left:-500px;'
          'width:1px;height:1px;opacity:0;pointer-events:none;';
    html.document.body?.append(_input!);
    _input!.onChange.listen(_handleChange);
  }

  void _handleChange(html.Event _) {
    final files = _input?.files;
    if (files == null || files.isEmpty) {
      _onCancel?.call();
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result != null) {
        try {
          final bytes = Uint8List.view(result as dynamic);
          _onSuccess?.call(bytes, file.name);
        } catch (_) {
          _onCancel?.call();
        }
      } else {
        _onCancel?.call();
      }
      _input?.value = ''; // 같은 파일 재선택 허용
    });
    reader.onError.listen((_) => _onCancel?.call());
    reader.readAsArrayBuffer(file);
  }

  /// onTap 에서 직접 호출 — 동기적으로 click() 실행
  /// 결과는 onSuccess / onCancel 콜백으로 수신
  void openPicker({
    required void Function(Uint8List bytes, String name) onSuccess,
    void Function()? onCancel,
  }) {
    _onSuccess = onSuccess;
    _onCancel = onCancel;
    _input?.click(); // 동기 호출 — 이벤트 컨텍스트 유지
  }

  /// 네이티브(Android/iOS)용 파일 선택
  static Future<(Uint8List, String)?> pickNative() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      return (bytes, file.name);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _input?.remove();
    _input = null;
  }
}
