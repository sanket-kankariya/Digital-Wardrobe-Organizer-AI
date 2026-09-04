import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/outfit_model.dart';
import '../services/database_service.dart';

final outfitCategoriesProvider = StateNotifierProvider<OutfitCategoriesNotifier, List<CategoryModel>>((ref) {
  return OutfitCategoriesNotifier();
});

class OutfitCategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  OutfitCategoriesNotifier() : super([]) {
    refresh();
  }

  void refresh() {
    state = DatabaseService.getCategories('outfit');
  }

  Future<void> addCategory(String name, int colorValue) async {
    await DatabaseService.addCategory(name, 'outfit', colorValue);
    refresh();
  }

  Future<void> renameCategory(String id, String newName) async {
    await DatabaseService.renameCategory(id, newName);
    refresh();
  }

  Future<void> deleteCategory(String id) async {
    await DatabaseService.deleteCategory(id);
    refresh();
  }
}

final outfitsByStyleProvider = StateNotifierProvider.family<OutfitsByStyleNotifier, List<OutfitModel>, String>((ref, styleId) {
  return OutfitsByStyleNotifier(styleId);
});

class OutfitsByStyleNotifier extends StateNotifier<List<OutfitModel>> {
  final String styleId;

  OutfitsByStyleNotifier(this.styleId) : super([]) {
    refresh();
  }

  void refresh() {
    state = DatabaseService.getOutfitsByStyle(styleId);
  }

  Future<void> addOutfit(String name, List<String> itemIds) async {
    await DatabaseService.addOutfit(name: name, styleId: styleId, itemIds: itemIds);
    refresh();
  }

  Future<void> deleteOutfit(String id) async {
    await DatabaseService.deleteOutfit(id);
    refresh();
  }
}

final allOutfitsProvider = Provider<List<OutfitModel>>((ref) {
  return DatabaseService.getAllOutfits();
});
