import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the system photo picker. On Android 13+ this needs no permission,
/// and the newest items (a reel you just downloaded) are at the top.
class MediaPicker {
  MediaPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<List<String>> video() async {
    try {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      return file == null ? const [] : [file.path];
    } catch (e) {
      debugPrint('Video picker failed: $e');
      return const [];
    }
  }

  Future<List<String>> images() async {
    try {
      final files = await _picker.pickMultiImage(limit: 10);
      return [for (final f in files) f.path];
    } catch (e) {
      debugPrint('Image picker failed: $e');
      return const [];
    }
  }
}
