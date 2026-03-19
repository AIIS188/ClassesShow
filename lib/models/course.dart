import 'package:hive/hive.dart';

part 'course.g.dart';

@HiveType(typeId: 0)
class Course {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final int weekday;

  @HiveField(2)
  final int startSection;

  @HiveField(3)
  final int endSection;

  @HiveField(4)
  final String location;

  @HiveField(5)
  final String teacher;

  @HiveField(6)
  final List<int> weeks;

  Course({
    required this.name,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.location,
    required this.teacher,
    required this.weeks,
  });
}