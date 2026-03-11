// PDF 파일 선택 유틸리티
// 핵심: input element를 초기화 시점에 DOM에 삽입
// onTap에서 직접 click() 호출 - 브라우저 이벤트 컨텍스트 유지
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

class PdfFilePicker {
  html.FileUploadInputElement? _input;
  Completer<(Uint8List, String)?>? _completer;

  PdfFilePicker() {
    _initInput();
  }

  void _initInput() {
    _input?.remove();
    _input = html.FileUploadInputElement()
      ..accept = '.pdf,application/pdf'
      ..style.cssText = 'position:fixed;top:-200px;left:-200px;opacity:0;width:0;height:0;overflow:hidden;';
    html.document.body?.append(_input!);

    _input!.onChange.listen(_onFileSelected);
  }

  void _onFileSelected(html.Event e) {
    final files = _input?.files;
    if (files == null || files.isEmpty) {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
      return;
    }

    final file = files[0];
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result != null && _completer != null && !_completer!.isCompleted) {
        try {
          final bytes = Uint8List.view(result as dynamic);
          _completer!.complete((bytes, file.name));
        } catch (_) {
          if (!_completer!.isCompleted) _completer!.complete(null);
        }
      } else if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
      // input 값 초기화 (같은 파일 재선택 가능)
      _input?.value = '';
    });

    reader.onError.listen((_) {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
      _input?.value = '';
    });

    reader.readAsArrayBuffer(file);
  }

  /// 동기적으로 파일 선택 창을 열고 결과를 Future로 반환
  /// onTap 콜백에서 호출 가능 (이벤트 컨텍스트 유지)
  Future<(Uint8List, String)?> pick() {
    // 이전 completer 정리
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
    _completer = Completer<(Uint8List, String)?>();

    // 동기적으로 클릭 (이벤트 컨텍스트 유지됨)
    _input?.click();

    // 타임아웃
    Future.delayed(const Duration(minutes: 5), () {
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
    });

    return _completer!.future;
  }

  void dispose() {
    _input?.remove();
    _input = null;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
  }
}

// 전역 인스턴스 (앱 시작 시 초기화)
PdfFilePicker? _pickerInstance;

PdfFilePicker _getPicker() {
  _pickerInstance ??= PdfFilePicker();
  return _pickerInstance!;
}

/// PDF 파일 선택 (간편 함수)
Future<(Uint8List, String)?> pickPdfFile() {
  return _getPicker().pick();
}
