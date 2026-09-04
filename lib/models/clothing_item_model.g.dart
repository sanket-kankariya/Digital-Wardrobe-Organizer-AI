// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clothing_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClothingItemModelAdapter extends TypeAdapter<ClothingItemModel> {
  @override
  final int typeId = 1;

  @override
  ClothingItemModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClothingItemModel(
      id: fields[0] as String,
      name: fields[1] as String,
      brand: fields[2] as String,
      colorValue: fields[3] as int,
      categoryId: fields[4] as String,
      imagePath: fields[5] as String,
      addedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ClothingItemModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClothingItemModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
