// 네이티브(Android/iOS) 플랫폼용 stub 구현
import 'dart:async';
import 'dart:typed_data';

void registerVideoViewFactory(String viewKey, String url) {
  // 네이티브에서는 HtmlElementView를 사용하지 않으므로 no-op
}

void registerRemoteVideoFactory(String viewKey, String fullUrl) {
  // 네이티브에서는 HtmlElementView를 사용하지 않으므로 no-op
}

String createBlobUrl(Uint8List bytes, String mime) {
  // 네이티브에서는 Blob URL이 없으므로 빈 문자열 반환
  return '';
}

Future<String> uploadFileXhr(
  String baseUrl,
  Uint8List bytes,
  String filename, {
  String Function(String name)? mimeType,
  void Function(double progress)? onProgress,
}) async {
  throw UnsupportedError('XHR upload is only supported on Web platform');
}
