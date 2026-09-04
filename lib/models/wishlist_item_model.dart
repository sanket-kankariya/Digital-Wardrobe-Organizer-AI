import 'package:hive/hive.dart';

part 'wishlist_item_model.g.dart';

@HiveType(typeId: 3)
class WishlistItemModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String brand;

  @HiveField(3)
  late int colorValue;

  @HiveField(4)
  late String imagePath;

  @HiveField(5)
  String? price;

  @HiveField(6)
  String? storeNote;

  @HiveField(7)
  late DateTime addedAt;

  WishlistItemModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.colorValue,
    required this.imagePath,
    this.price,
    this.storeNote,
    required this.addedAt,
  });
}
