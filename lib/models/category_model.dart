import 'package:hive/hive.dart';

part 'category_model.g.dart';

@HiveType(typeId: 0)
class CategoryModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String type; // 'wardrobe' or 'outfit'

  @HiveField(3)
  late int colorValue;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF2874F0,
  });
}
