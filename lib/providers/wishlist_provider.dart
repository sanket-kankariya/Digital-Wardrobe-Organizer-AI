import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wishlist_item_model.dart';
import '../services/database_service.dart';

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<WishlistItemModel>>((ref) {
  return WishlistNotifier();
});

class WishlistNotifier extends StateNotifier<List<WishlistItemModel>> {
  WishlistNotifier() : super([]) {
    refresh();
  }

  void refresh() {
    state = DatabaseService.getWishlist();
  }

  Future<void> addItem({
    required String name,
    required String brand,
    required int colorValue,
    required String imagePath,
    String? price,
    String? storeNote,
  }) async {
    await DatabaseService.addWishlistItem(
      name: name,
      brand: brand,
      colorValue: colorValue,
      imagePath: imagePath,
      price: price,
      storeNote: storeNote,
    );
    refresh();
  }

  Future<void> deleteItem(String id) async {
    await DatabaseService.deleteWishlistItem(id);
    refresh();
  }

  Future<void> moveToWardrobe(WishlistItemModel item, String categoryId) async {
    await DatabaseService.moveWishlistToWardrobe(item, categoryId);
    refresh();
  }
}
