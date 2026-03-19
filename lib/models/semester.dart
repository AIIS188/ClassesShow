import 'package:hive/hive.dart';

part 'semester.g.dart';

@HiveType(typeId: 1)
class Semester extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  bool isActive;

  @HiveField(3)
  DateTime createdAt;

  Semester({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });
}