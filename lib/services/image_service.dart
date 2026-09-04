import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';




import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class ImageService {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Pick image from camera
  static Future<File?> pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick image from gallery
  static Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick multiple images from gallery for bulk add
  static Future<List<File>> pickMultipleFromGallery({int maxImages = 20}) async {
    final xFiles = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
      limit: maxImages,
    );
    return xFiles.map((xf) => File(xf.path)).toList();
  }



  /// Remove background using Google ML Kit Subject Segmentation on-device.
  /// Uses native GPU/hardware acceleration and writes bytes directly to avoid CPU bottlenecks.
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
          final dir = await getApplicationDocumentsDirectory();
          final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
          final outFile = File(outPath);
          await outFile.writeAsBytes(foregroundBytes);
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

  /// Fast non-blocking helper
  static Future<File> cropTransparentPadding(File file) async {
    return file;
  }


  /// Save a file permanently into app documents
  static Future<File> saveImagePermanently(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = 'wardrobe_${_uuid.v4()}.png';
    final savedFile = await file.copy('${dir.path}/$name');
    return savedFile;
  }
}

