// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      name: fields[0] as String,
      weekday: fields[1] as int,
      startSection: fields[2] as int,
      endSection: fields[3] as int,
      location: fields[4] as String,
      teacher: fields[5] as String,
      weeks: (fields[6] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.weekday)
      ..writeByte(2)
      ..write(obj.startSection)
      ..writeByte(3)
      ..write(obj.endSection)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.teacher)
      ..writeByte(6)
      ..write(obj.weeks);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
