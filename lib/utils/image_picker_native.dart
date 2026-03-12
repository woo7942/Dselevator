import 'package:file_picker/file_picker.dart';
import 'image_picker_util.dart';

/// 네이티브(Android/iOS) 플랫폼 전용 이미지 선택기

class ImageFilePicker {
  Future<List<PickedImage>?> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;

      final images = <PickedImage>[];
      for (final f in result.files) {
        if (f.bytes != null) {
          images.add(PickedImage(f.bytes!, f.name));
        }
      }
      return images.isEmpty ? null : images;
    } catch (_) {
      return null;
    }
  }

  void openPicker({
    required void Function(List<PickedImage> images) onSuccess,
    void Function(String error)? onError,
  }) {
    pick().then((images) {
      if (images != null && images.isNotEmpty) {
        onSuccess(images);
      }
    }).catchError((e) {
      onError?.call(e.toString());
    });
  }

  void dispose() {}
}

/// 네이티브에서 이미지 선택 (단일)
Future<PickedImage?> pickSingleImage() async {
  final picker = ImageFilePicker();
  final result = await picker.pick();
  return result?.firstOrNull;
}
