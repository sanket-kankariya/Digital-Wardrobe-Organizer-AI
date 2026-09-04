import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/category_model.dart';
import '../models/clothing_item_model.dart';
import '../models/outfit_model.dart';
import '../models/wishlist_item_model.dart';

class DatabaseService {
  static const _categoriesBox = 'categories';
  static const _itemsBox = 'clothing_items';
  static const _outfitsBox = 'outfits';
  static const _wishlistBox = 'wishlist';

  static final _uuid = Uuid();

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(ClothingItemModelAdapter());
    Hive.registerAdapter(OutfitModelAdapter());
    Hive.registerAdapter(WishlistItemModelAdapter());

    await Hive.openBox<CategoryModel>(_categoriesBox);
    await Hive.openBox<ClothingItemModel>(_itemsBox);
    await Hive.openBox<OutfitModel>(_outfitsBox);
    await Hive.openBox<WishlistItemModel>(_wishlistBox);

    _seedDefaultCategories();
  }

  static void _seedDefaultCategories() {
    final box = Hive.box<CategoryModel>(_categoriesBox);
    if (box.isEmpty) {
      final defaults = [
        CategoryModel(id: _uuid.v4(), name: 'Tops', type: 'wardrobe', colorValue: 0xFF2874F0),
        CategoryModel(id: _uuid.v4(), name: 'Bottoms', type: 'wardrobe', colorValue: 0xFF1565C0),
        CategoryModel(id: _uuid.v4(), name: 'Outerwear', type: 'wardrobe', colorValue: 0xFF0288D1),
        CategoryModel(id: _uuid.v4(), name: 'Activewear', type: 'wardrobe', colorValue: 0xFF00897B),
        CategoryModel(id: _uuid.v4(), name: 'Shoes', type: 'wardrobe', colorValue: 0xFF6A1B9A),
        CategoryModel(id: _uuid.v4(), name: 'Accessories', type: 'wardrobe', colorValue: 0xFFAD1457),
        CategoryModel(id: _uuid.v4(), name: 'Work', type: 'outfit', colorValue: 0xFF1565C0),
        CategoryModel(id: _uuid.v4(), name: 'Formal', type: 'outfit', colorValue: 0xFF4A148C),
        CategoryModel(id: _uuid.v4(), name: 'Casual', type: 'outfit', colorValue: 0xFF2874F0),
        CategoryModel(id: _uuid.v4(), name: 'Sports', type: 'outfit', colorValue: 0xFF00897B),
        CategoryModel(id: _uuid.v4(), name: 'Party', type: 'outfit', colorValue: 0xFFAD1457),
      ];
      for (final cat in defaults) {
        box.put(cat.id, cat);
      }
    }
  }

  // -- Categories --------------------------------------------------
  static Box<CategoryModel> get _catBox => Hive.box<CategoryModel>(_categoriesBox);

  static List<CategoryModel> getCategories(String type) =>
      _catBox.values.where((c) => c.type == type).toList();

  static Future<void> addCategory(String name, String type, int colorValue) async {
    final cat = CategoryModel(id: _uuid.v4(), name: name, type: type, colorValue: colorValue);
    await _catBox.put(cat.id, cat);
  }

  static Future<void> renameCategory(String id, String newName) async {
    final cat = _catBox.get(id);
    if (cat != null) {
      cat.name = newName;
      await cat.save();
    }
  }

  static Future<void> deleteCategory(String id) async {
    await _catBox.delete(id);
  }

  // -- Clothing Items -----------------------------------------------
  static Box<ClothingItemModel> get _itemsBoxRef => Hive.box<ClothingItemModel>(_itemsBox);

  static List<ClothingItemModel> getItemsByCategory(String categoryId) =>
      _itemsBoxRef.values.where((i) => i.categoryId == categoryId).toList();

  static List<ClothingItemModel> getAllItems() => _itemsBoxRef.values.toList();

  static Future<String> addItem({
    required String name,
    required String brand,
    required int colorValue,
    required String categoryId,
    required String imagePath,
  }) async {
    final item = ClothingItemModel(
      id: _uuid.v4(),
      name: name,
      brand: brand,
      colorValue: colorValue,
      categoryId: categoryId,
      imagePath: imagePath,
      addedAt: DateTime.now(),
    );
    await _itemsBoxRef.put(item.id, item);
    return item.id;
  }

  static Future<void> updateItem(ClothingItemModel item) async {
    await item.save();
  }

  static Future<void> deleteItem(String id) async {
    await _itemsBoxRef.delete(id);
  }

  // -- Outfits ------------------------------------------------------
  static Box<OutfitModel> get _outfitsBoxRef => Hive.box<OutfitModel>(_outfitsBox);

  static List<OutfitModel> getOutfitsByStyle(String styleId) =>
      _outfitsBoxRef.values.where((o) => o.styleId == styleId).toList();

  static List<OutfitModel> getAllOutfits() => _outfitsBoxRef.values.toList();

  static Future<void> addOutfit({
    required String name,
    required String styleId,
    required List<String> itemIds,
  }) async {
    final outfit = OutfitModel(
      id: _uuid.v4(),
      name: name,
      styleId: styleId,
      itemIds: itemIds,
      createdAt: DateTime.now(),
    );
    await _outfitsBoxRef.put(outfit.id, outfit);
  }

  static Future<void> deleteOutfit(String id) async {
    await _outfitsBoxRef.delete(id);
  }

  // -- Wishlist -----------------------------------------------------
  static Box<WishlistItemModel> get _wishlistBoxRef => Hive.box<WishlistItemModel>(_wishlistBox);

  static List<WishlistItemModel> getWishlist() => _wishlistBoxRef.values.toList();

  static Future<void> addWishlistItem({
    required String name,
    required String brand,
    required int colorValue,
    required String imagePath,
    String? price,
    String? storeNote,
  }) async {
    final item = WishlistItemModel(
      id: _uuid.v4(),
      name: name,
      brand: brand,
      colorValue: colorValue,
      imagePath: imagePath,
      price: price,
      storeNote: storeNote,
      addedAt: DateTime.now(),
    );
    await _wishlistBoxRef.put(item.id, item);
  }

  static Future<void> deleteWishlistItem(String id) async {
    await _wishlistBoxRef.delete(id);
  }

  static Future<void> moveWishlistToWardrobe(
      WishlistItemModel wishItem, String categoryId) async {
    await addItem(
      name: wishItem.name,
      brand: wishItem.brand,
      colorValue: wishItem.colorValue,
      categoryId: categoryId,
      imagePath: wishItem.imagePath,
    );
    await deleteWishlistItem(wishItem.id);
  }
}
