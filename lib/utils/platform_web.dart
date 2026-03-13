// 웹 플랫폼 전용 구현 (dart.library.html 환경에서만 사용)
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerVideoViewFactory(String viewKey, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewKey, (int _) {
    final video = web.HTMLVideoElement()
      ..src = url
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.borderRadius = '0 0 12px 12px'
      ..style.backgroundColor = '#000';
    return video;
  });
}

void registerRemoteVideoFactory(String viewKey, String fullUrl) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewKey,
    (int viewId) {
      final video = web.HTMLVideoElement()
        ..src = fullUrl
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '12px'
        ..style.backgroundColor = '#000';
      return video;
    },
  );
}

String createBlobUrl(Uint8List bytes, String mime) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  return web.URL.createObjectURL(blob);
}

Future<String> uploadFileXhr(
  String baseUrl,
  Uint8List bytes,
  String filename, {
  String Function(String name)? mimeType,
  void Function(double progress)? onProgress,
}) {
  final completer = Completer<String>();
  final uri = '$baseUrl/api/upload';
  final fileMB = bytes.length / (1024 * 1024);
  final timeoutMs = ((120 + fileMB * 5).clamp(120, 600) * 1000).toInt();

  final xhr = web.XMLHttpRequest();
  xhr.open('POST', uri);
  xhr.timeout = timeoutMs;

  xhr.upload.addEventListener('progress', ((web.Event e) {
    if (completer.isCompleted) return;
    final pe = e as web.ProgressEvent;
    if (pe.lengthComputable && pe.total > 0) {
      onProgress?.call((pe.loaded / pe.total) * 0.9);
    }
  }).toJS);

  xhr.addEventListener('load', ((web.Event _) {
    if (completer.isCompleted) return;
    onProgress?.call(1.0);
    try {
      if (xhr.status == 200) {
        final data = jsonDecode(xhr.responseText) as Map<String, dynamic>;
        if (data['success'] == true) {
          final list = data['urls'];
          if (list is List && list.isNotEmpty) {
            completer.complete(list.first.toString());
          } else {
            completer.completeError(Exception('서버에서 URL을 반환하지 않았습니다'));
          }
        } else {
          completer.completeError(Exception(data['error']?.toString() ?? '업로드 오류'));
        }
      } else {
        completer.completeError(Exception('업로드 실패 (HTTP ${xhr.status})'));
      }
    } catch (e) {
      completer.completeError(Exception('응답 파싱 오류: $e'));
    }
  }).toJS);

  xhr.addEventListener('error', ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('네트워크 오류'));
    }
  }).toJS);

  xhr.addEventListener('timeout', ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('업로드 타임아웃'));
    }
  }).toJS);

  xhr.addEventListener('abort', ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('업로드 취소'));
    }
  }).toJS);

  final mime = mimeType?.call(filename) ?? 'application/octet-stream';
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final formData = web.FormData();
  formData.append('files', blob, filename);
  xhr.send(formData);

  return completer.future;
}
