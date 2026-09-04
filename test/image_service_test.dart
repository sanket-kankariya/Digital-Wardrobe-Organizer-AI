import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('Cropping transparent padding correctly tightens image bounds', () {
    // Create an image with transparent background (100x100)
    final testImage = img.Image(width: 100, height: 100, numChannels: 4);

    // Fill only a 20x20 area in the center (from x=40..60, y=40..60) with opaque red
    for (int y = 40; y < 60; y++) {
      for (int x = 40; x < 60; x++) {
        testImage.setPixel(x, y, img.ColorRgba8(255, 0, 0, 255));
      }
    }

    final encoded = Uint8List.fromList(img.encodePng(testImage));

    // Decode and calculate bounding box
    final src = img.decodeImage(encoded)!;
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

    expect(minX, equals(40));
    expect(maxX, equals(59));
    expect(minY, equals(40));
    expect(maxY, equals(59));

    const padding = 5;
    final cropX = (minX - padding).clamp(0, src.width - 1);
    final cropY = (minY - padding).clamp(0, src.height - 1);
    final cropMaxX = (maxX + padding).clamp(0, src.width - 1);
    final cropMaxY = (maxY + padding).clamp(0, src.height - 1);
    final cropW = cropMaxX - cropX + 1;
    final cropH = cropMaxY - cropY + 1;

    final cropped = img.copyCrop(src, x: cropX, y: cropY, width: cropW, height: cropH);
    // Width and height should now be tightened from 100x100 to 30x30
    expect(cropped.width, equals(30));
    expect(cropped.height, equals(30));
  });
}
