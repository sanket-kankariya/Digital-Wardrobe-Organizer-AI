import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

class ImageService {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  /// Pick image from camera
  static Future<File?> pickFromCamera() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick image from gallery
  static Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Remove background using Google ML Kit Subject Segmentation on-device.
  /// Falls back to luminance/color thresholding if ML segmentation is unavailable.
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
      debugPrint('Google ML Kit Subject Segmentation failed: $e. Falling back to thresholding...');
    }

    // Fallback: Color/Luminance thresholding
    final bytes = await inputFile.readAsBytes();
    final processed = await compute(_processImage, bytes);
    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
    final outFile = File(outPath);
    await outFile.writeAsBytes(processed);
    return outFile;
  }


  /// Save a file permanently into app documents
  static Future<File> saveImagePermanently(File file) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = 'wardrobe_${_uuid.v4()}.png';
    final savedFile = await file.copy('${dir.path}/$name');
    return savedFile;
  }

  /// Run background removal in isolate
  static Uint8List _processImage(Uint8List bytes) {
    final src = img.decodeImage(bytes);
    if (src == null) return bytes;

    final result = img.Image(width: src.width, height: src.height);

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Determine if pixel is background (light/white)
        final brightness = (r * 0.299 + g * 0.587 + b * 0.114);
        final isWhitish = brightness > 220 && (r - g).abs() < 30 && (r - b).abs() < 30;
        final isLightGray = brightness > 200 && (r - g).abs() < 20 && (r - b).abs() < 20;

        if (isWhitish || isLightGray) {
          result.setPixel(x, y, img.ColorRgba8(r, g, b, 0));
        } else {
          result.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
        }
      }
    }

    return Uint8List.fromList(img.encodePng(result));
  }
}
