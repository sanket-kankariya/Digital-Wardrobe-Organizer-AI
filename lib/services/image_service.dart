import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';




import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class ImageService {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Pick image from camera with high/original quality (up to 2560px, 100% quality)
  static Future<File?> pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      maxWidth: 2560,
      maxHeight: 2560,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick image from gallery with high/original quality (up to 2560px, 100% quality)
  static Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      maxWidth: 2560,
      maxHeight: 2560,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick multiple images from gallery for bulk add with high quality (up to 2560px, 100% quality)
  static Future<List<File>> pickMultipleFromGallery({int maxImages = 20}) async {
    final xFiles = await _picker.pickMultiImage(
      imageQuality: 100,
      maxWidth: 2560,
      maxHeight: 2560,
      limit: maxImages,
    );
    return xFiles.map((xf) => File(xf.path)).toList();
  }



  /// Remove background using Google ML Kit Subject Segmentation on-device,
  /// and automatically trim transparent padding so the subject fits tightly to the box.
  static Future<File> removeBackground(File inputFile) async {
    try {
      final inputImage = InputImage.fromFile(inputFile);
      final options = SubjectSegmenterOptions(
        enableForegroundBitmap: true,
        enableForegroundConfidenceMask: false,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      );
      final segmenter = SubjectSegmenter(options: options);

      try {
        final result = await segmenter.processImage(inputImage);
        final foregroundBytes = result.foregroundBitmap;

        if (foregroundBytes != null && foregroundBytes.isNotEmpty) {
          // Trim transparent outer padding so the clothing item fits tightly to the box
          final trimmedBytes = await compute(_trimTransparentBorders, foregroundBytes);

          final dir = await getApplicationDocumentsDirectory();
          final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
          final outFile = File(outPath);
          await outFile.writeAsBytes(trimmedBytes ?? foregroundBytes);
          return outFile;
        }
      } finally {
        await segmenter.close();
      }
    } catch (e) {
      debugPrint('Google ML Kit Subject Segmentation failed: $e. Using original photo...');
    }

    // Fast fallback: If ML Kit is not available, copy file directly without CPU loops
    return await saveImagePermanently(inputFile);
  }

  /// Crop transparent padding from an existing file
  static Future<File> cropTransparentPadding(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final trimmedBytes = await compute(_trimTransparentBorders, bytes);
      if (trimmedBytes != null) {
        await file.writeAsBytes(trimmedBytes);
      }
    } catch (e) {
      debugPrint('cropTransparentPadding failed: $e');
    }
    return file;
  }

  /// Save a file permanently into app documents
  static Future<File> saveImagePermanently(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    if (file.parent.path == dir.path && file.path.contains('wardrobe_')) {
      return file;
    }
    final ext = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final name = 'wardrobe_${_uuid.v4()}.$ext';
    final savedFile = await file.copy('${dir.path}/$name');
    return savedFile;
  }
}

/// Top-level function for background isolate computation: trims all transparent outer padding
Uint8List? _trimTransparentBorders(Uint8List rawBytes) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;
    final trimmed = img.trim(decoded, mode: img.TrimMode.transparent);
    if (trimmed.width > 0 && trimmed.height > 0) {
      return Uint8List.fromList(img.encodePng(trimmed));
    }
  } catch (e) {
    debugPrint('Failed to trim transparent borders: $e');
  }
  return null;
}

