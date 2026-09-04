import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../models/clothing_item_model.dart';
import '../services/database_service.dart';

// Categories
final wardrobeCategoriesProvider = StateNotifierProvider<WardrobeCategoriesNotifier, List<CategoryModel>>((ref) {
  return WardrobeCategoriesNotifier();
});

class WardrobeCategoriesNotifier extends StateNotifier<List<CategoryModel>> {
  WardrobeCategoriesNotifier() : super([]) {
    refresh();
  }

  void refresh() {
    state = DatabaseService.getCategories('wardrobe');
  }

  Future<void> addCategory(String name, int colorValue) async {
    await DatabaseService.addCategory(name, 'wardrobe', colorValue);
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

// Items by category
final categoryItemsProvider = StateNotifierProvider.family<CategoryItemsNotifier, List<ClothingItemModel>, String>((ref, categoryId) {
  return CategoryItemsNotifier(categoryId);
});

class CategoryItemsNotifier extends StateNotifier<List<ClothingItemModel>> {
  final String categoryId;

  CategoryItemsNotifier(this.categoryId) : super([]) {
    refresh();
  }

  void refresh() {
    state = DatabaseService.getItemsByCategory(categoryId);
  }

  Future<void> addItem({
    required String name,
    required String brand,
    required int colorValue,
    required String imagePath,
  }) async {
    await DatabaseService.addItem(
      name: name,
      brand: brand,
      colorValue: colorValue,
      categoryId: categoryId,
      imagePath: imagePath,
    );
    refresh();
  }

  Future<void> deleteItem(String id) async {
    await DatabaseService.deleteItem(id);
    refresh();
  }

  void sortByName() {
    state = [...state]..sort((a, b) => a.name.compareTo(b.name));
  }

  void sortByRecent() {
    state = [...state]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  void sortByColor() {
    state = [...state]..sort((a, b) => a.colorValue.compareTo(b.colorValue));
  }
}

// All items (for stats)
final allItemsProvider = Provider<List<ClothingItemModel>>((ref) {
  return DatabaseService.getAllItems();
});
