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
      imageQuality: 75,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (xFile == null) return null;
    return File(xFile.path);
  }

  /// Pick image from gallery
  static Future<File?> pickFromGallery() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 600,
      maxHeight: 600,
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
          // Auto-trim transparent borders so the subject scales to fit
          final trimmedBytes = await compute(_trimTransparent, foregroundBytes);
          final dir = await getApplicationDocumentsDirectory();
          final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
          final outFile = File(outPath);
          await outFile.writeAsBytes(trimmedBytes);
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
    final trimmedBytes = await compute(_trimTransparent, processed);
    final dir = await getApplicationDocumentsDirectory();
    final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
    final outFile = File(outPath);
    await outFile.writeAsBytes(trimmedBytes);
    return outFile;
  }

  /// Crop transparent padding around an image file so the subject scales to fit
  static Future<File> cropTransparentPadding(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final trimmed = await compute(_trimTransparent, bytes);
      final dir = await getApplicationDocumentsDirectory();
      final outPath = '${dir.path}/wardrobe_${_uuid.v4()}.png';
      final outFile = File(outPath);
      await outFile.writeAsBytes(trimmed);
      return outFile;
    } catch (_) {
      return file;
    }
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

    final result = img.Image(width: src.width, height: src.height, numChannels: 4);

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

  /// Trim transparent borders around the subject so it scales to fit the container.
  static Uint8List _trimTransparent(Uint8List bytes) {
    final src = img.decodeImage(bytes);
    if (src == null || src.numChannels < 4) return bytes;

    int minX = src.width;
    int minY = src.height;
    int maxX = -1;
    int maxY = -1;

    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        final pixel = src.getPixel(x, y);
        if (pixel.a > 15) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    // No non-transparent pixels found or invalid bounding box
    if (maxX < minX || maxY < minY) {
      return bytes;
    }

    // Add safe padding (10px) around subject so edge pixels remain smooth
    const padding = 10;
    final cropX = (minX - padding).clamp(0, src.width - 1);
    final cropY = (minY - padding).clamp(0, src.height - 1);
    final cropMaxX = (maxX + padding).clamp(0, src.width - 1);
    final cropMaxY = (maxY + padding).clamp(0, src.height - 1);
    final cropW = cropMaxX - cropX + 1;
    final cropH = cropMaxY - cropY + 1;

    if (cropW <= 0 || cropH <= 0) return bytes;

    final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);
    return Uint8List.fromList(img.encodePng(cropped));
  }
}
