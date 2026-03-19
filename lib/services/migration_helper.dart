import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import 'semester_storage.dart';

/// 从旧版 CourseStorage（courses box）迁移到 SemesterStorage。
/// 只执行一次，迁移后标记完成。
class MigrationHelper {
  static const _migratedKey = 'migrated_to_semester_v1';

  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    // 旧 box 是否存在且有数据
    if (!Hive.isBoxOpen('courses')) {
      try {
        await Hive.openBox<Course>('courses');
      } catch (_) {
        // box 不存在，无需迁移
        await prefs.setBool(_migratedKey, true);
        return;
      }
    }

    final oldBox = Hive.box<Course>('courses');
    final oldCourses = oldBox.values.toList();

    if (oldCourses.isNotEmpty) {
      // 找到或创建默认学期
      var semesters = SemesterStorage.getAll();
      final String targetId;
      if (semesters.isEmpty) {
        targetId = await SemesterStorage.create('默认1');
      } else {
        // 写入第一个（最早）学期
        targetId = semesters.first.id;
      }

      // 迁移课程（去重：按 name+weekday+startSection 判断）
      final existing = SemesterStorage.getCourses(targetId);
      final existingKeys = existing
          .map((c) => '${c.name}_${c.weekday}_${c.startSection}')
          .toSet();

      for (final c in oldCourses) {
        final key = '${c.name}_${c.weekday}_${c.startSection}';
        if (!existingKeys.contains(key)) {
          await SemesterStorage.addCourse(targetId, c);
          existingKeys.add(key);
        }
      }

      // 清空旧 box
      await oldBox.clear();
    }

    await prefs.setBool(_migratedKey, true);
  }
}