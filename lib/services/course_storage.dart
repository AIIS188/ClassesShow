import 'package:hive/hive.dart';
import '../models/course.dart';

class CourseStorage {
  static final Box<Course> _box = Hive.box<Course>('courses');

  /// 获取所有课程
  static List<Course> getCourses() {
    return _box.values.toList();
  }

  /// 添加课程
  static Future<void> addCourse(Course course) async {
    await _box.add(course);
  }

  /// 删除课程
  static Future<void> deleteCourse(int index) async {
    await _box.deleteAt(index);
  }

  /// 清空（调试用）
  static Future<void> clear() async {
    await _box.clear();
  }
}