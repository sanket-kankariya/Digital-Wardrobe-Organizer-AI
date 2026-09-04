import 'dart:io';
import 'package:flutter/material.dart';

/// Transient data model for each item during the bulk-add review phase.
/// Not persisted to Hive — only lives in memory during the wizard flow.
class BulkItemData {
  /// Original picked image file
  File imageFile;

  /// Processed image after background removal (null = still processing)
  File? processedImage;

  /// Item name (pre-filled by AI or entered manually)
  String name;

  /// Brand name
  String brand;

  /// Selected color for this item
  Color selectedColor;

  /// Category ID chosen or AI-suggested
  String? categoryId;

  /// Whether background removal is in progress
  bool isProcessingBg;

  /// Whether AI analysis is in progress
  bool isAnalyzingAi;

  /// Whether the user chose to skip/remove this item
  bool isRemoved;

  BulkItemData({
    required this.imageFile,
    this.processedImage,
    this.name = '',
    this.brand = '',
    this.selectedColor = const Color(0xFF2874F0),
    this.categoryId,
    this.isProcessingBg = false,
    this.isAnalyzingAi = false,
    this.isRemoved = false,
  });

  /// The best available image (processed if ready, otherwise original)
  File get displayImage => processedImage ?? imageFile;

  /// Delete temporary processed image to prevent orphaned files
  Future<void> cleanup() async {
    if (processedImage != null && processedImage!.path != imageFile.path) {
      try {
        if (await processedImage!.exists()) {
          await processedImage!.delete();
        }
      } catch (_) {}
    }
  }

  /// Clean up all unsaved items in a list
  static Future<void> cleanupAll(List<BulkItemData> items) async {
    for (final item in items) {
      await item.cleanup();
    }
  }
}
