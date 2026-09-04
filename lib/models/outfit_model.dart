import 'package:hive/hive.dart';

part 'outfit_model.g.dart';

@HiveType(typeId: 2)
class OutfitModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late String styleId;

  @HiveField(3)
  late List<String> itemIds;

  @HiveField(4)
  late DateTime createdAt;

  OutfitModel({
    required this.id,
    required this.name,
    required this.styleId,
    required this.itemIds,
    required this.createdAt,
  });
}
