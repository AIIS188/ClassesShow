// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'semester.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SemesterAdapter extends TypeAdapter<Semester> {
  @override
  final int typeId = 1;

  @override
  Semester read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Semester(
      id: fields[0] as String,
      name: fields[1] as String,
      isActive: fields[2] as bool,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Semester obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isActive)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemesterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
