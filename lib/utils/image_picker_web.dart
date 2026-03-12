import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'image_picker_util.dart';

/// 웹 플랫폼 전용 이미지 파일 선택기
/// package:web + dart:js_interop 사용
class ImageFilePicker {
  web.HTMLInputElement? _input;
  Completer<List<PickedImage>?>? _completer;
  JSFunction? _changeHandler;

  ImageFilePicker() {
    _input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/*,video/*'
      ..multiple = true;

    _input!.style
      ..position = 'fixed'
      ..opacity = '0'
      ..top = '-9999px'
      ..left = '-9999px'
      ..width = '1px'
      ..height = '1px';

    web.document.body!.append(_input!);

    // Change 이벤트 리스너 등록
    _changeHandler = ((web.Event _) => _handleChange()).toJS;
    _input!.addEventListener('change', _changeHandler!);
  }

  void _handleChange() {
    final files = _input?.files;
    if (files == null || files.length == 0) {
      _completer?.complete(null);
      _completer = null;
      return;
    }

    _readAllFiles(files).then((results) {
      _input?.value = '';
      _completer?.complete(results.isEmpty ? null : results);
      _completer = null;
    });
  }

  Future<List<PickedImage>> _readAllFiles(web.FileList files) async {
    final results = <PickedImage>[];
    final count = files.length;
    for (int i = 0; i < count; i++) {
      final file = files.item(i);
      if (file == null) continue;
      try {
        final bytes = await _readFileBytes(file);
        if (bytes != null) {
          results.add(PickedImage(bytes, file.name));
        }
      } catch (_) {}
    }
    return results;
  }

  Future<Uint8List?> _readFileBytes(web.File file) {
    final completer = Completer<Uint8List?>();
    final reader = web.FileReader();

    reader.addEventListener(
      'loadend',
      ((web.Event _) {
        final result = reader.result;
        if (result != null) {
          try {
            final buffer = (result as JSArrayBuffer).toDart;
            completer.complete(buffer.asUint8List());
          } catch (_) {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      }).toJS,
    );

    reader.addEventListener(
      'error',
      ((web.Event _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
    );

    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  /// 콜백 방식 — onTap 동기 컨텍스트에서 click() 호출
  void openPicker({
    required void Function(List<PickedImage> images) onSuccess,
    void Function(String error)? onError,
  }) {
    _completer = Completer<List<PickedImage>?>();
    _input?.click(); // 동기 click — 사용자 이벤트 스택 내 실행

    _completer!.future.then((images) {
      if (images != null && images.isNotEmpty) onSuccess(images);
    }).catchError((Object e) {
      onError?.call(e.toString());
    });

    // 5분 타임아웃
    Future.delayed(const Duration(minutes: 5), () {
      if (!(_completer?.isCompleted ?? true)) {
        _completer?.complete(null);
        _completer = null;
      }
    });
  }

  /// Future 방식
  Future<List<PickedImage>?> pick() {
    _completer = Completer<List<PickedImage>?>();
    _input?.click();

    Future.delayed(const Duration(minutes: 5), () {
      if (!(_completer?.isCompleted ?? true)) {
        _completer?.complete(null);
        _completer = null;
      }
    });
    return _completer!.future;
  }

  void dispose() {
    if (_changeHandler != null) {
      _input?.removeEventListener('change', _changeHandler!);
    }
    _input?.remove();
    _input = null;
    _changeHandler = null;
    if (!(_completer?.isCompleted ?? true)) _completer?.complete(null);
    _completer = null;
  }
}
