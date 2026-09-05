import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ClothingTagResult {
  final String name;
  final String? brand;
  final int? colorValue;
  final String? categorySuggestion;

  ClothingTagResult({
    required this.name,
    this.brand,
    this.colorValue,
    this.categorySuggestion,
  });
}

class AiService {
  static const _storage = FlutterSecureStorage();
  static const _apiKeyStorageKey = 'gemini_api_key';

  // Primary model and fallback chain in order of availability and stability
  static const List<String> _models = [
    'gemini-3.6-flash',
    'gemini-1.5-flash',
    'gemini-3.8-flash',
  ];


  static Future<void> saveApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyStorageKey, value: apiKey.trim());
  }

  static Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKeyStorageKey);
  }

  static Future<void> deleteApiKey() async {
    await _storage.delete(key: _apiKeyStorageKey);
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  static Future<bool> validateApiKey(String apiKey) async {
    for (final modelName in _models) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey.trim(),
        );
        final response = await model.generateContent([
          Content.text('Hello'),
        ]);
        if (response.text != null) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  static Future<ClothingTagResult?> analyzeClothingImage({
    required File imageFile,
    List<String> existingCategories = const [],
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw Exception('API Key not found. Please set your Gemini API key.');
    }

    dynamic lastError;

    // Try models in sequence until one succeeds
    for (final modelName in _models) {
      try {
        debugPrint('Analyzing clothing image using model: $modelName...');
        return await _callGeminiVision(
          apiKey: apiKey.trim(),
          modelName: modelName,
          imageFile: imageFile,
          existingCategories: existingCategories,
        );
      } catch (e) {
        lastError = e;
        debugPrint('Model $modelName failed ($e). Trying next available model...');
      }
    }

    throw Exception('All AI models are currently busy or unavailable. Please try again in a moment. ($lastError)');
  }


  static Future<ClothingTagResult?> _callGeminiVision({
    required String apiKey,
    required String modelName,
    required File imageFile,
    required List<String> existingCategories,
  }) async {
    final model = GenerativeModel(
      model: modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        maxOutputTokens: 250,
        temperature: 0.2,
      ),
    );

    final imageBytes = await imageFile.readAsBytes();
    final mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final imagePart = DataPart(mimeType, imageBytes);

    final catHint = existingCategories.isNotEmpty
        ? 'Categories: ${existingCategories.join(", ")}.'
        : 'Categories: Tops, Bottoms, Outerwear, Shoes, Accessories, Dresses.';

    final prompt = TextPart('''
Identify clothing. Return JSON:
$catHint
{"name":"Item name (short)","brand":"Brand or null","dominantColorHex":"#RRGGBB","category":"Matched category"}
''');

    final response = await model.generateContent([
      Content.multi([prompt, imagePart]),
    ]);


    final rawText = response.text;
    if (rawText == null || rawText.trim().isEmpty) return null;

    final parsed = jsonDecode(rawText) as Map<String, dynamic>;
    final name = parsed['name'] as String? ?? '';
    final brand = parsed['brand'] as String?;
    final colorHex = parsed['dominantColorHex'] as String?;
    final category = parsed['category'] as String?;

    int? colorValue;
    if (colorHex != null) {
      final cleanHex = colorHex.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        colorValue = int.tryParse('FF$cleanHex', radix: 16);
      }
    }

    return ClothingTagResult(
      name: name,
      brand: brand,
      colorValue: colorValue,
      categorySuggestion: category,
    );
  }
}
