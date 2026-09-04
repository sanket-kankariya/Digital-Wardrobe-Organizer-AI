import 'package:hive/hive.dart';

part 'clothing_item_model.g.dart';

@HiveType(typeId: 1)
class ClothingItemModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String brand;

  @HiveField(3)
  late int colorValue;

  @HiveField(4)
  late String categoryId;

  @HiveField(5)
  late String imagePath;

  @HiveField(6)
  late DateTime addedAt;

  ClothingItemModel({
    required this.id,
    required this.name,
    required this.brand,
    required this.colorValue,
    required this.categoryId,
    required this.imagePath,
    required this.addedAt,
  });
}
