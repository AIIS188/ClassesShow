import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/course.dart';
import '../models/semester.dart';

/// 学期存储：
/// - semesters box：存 Semester 对象列表
/// - courses_{semesterId} box：每个学期独立一个 Course box
class SemesterStorage {
  static const _semestersBox = 'semesters';
  static const _uuid = Uuid();

  static Box<Semester> get _box => Hive.box<Semester>(_semestersBox);

  // ── 学期 CRUD ───────────────────────────────────────

  static List<Semester> getAll() =>
      _box.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  static Semester? getActive() {
    try {
      return _box.values.firstWhere((s) => s.isActive);
    } catch (_) {
      return _box.values.isNotEmpty ? _box.values.first : null;
    }
  }

  /// 创建新学期，返回学期 id
  static Future<String> create(String name) async {
    final id = _uuid.v4();
    await _box.put(id, Semester(
      id:        id,
      name:      name,
      isActive:  _box.isEmpty, // 第一个学期自动激活
      createdAt: DateTime.now(),
    ));
    // 确保对应的课程 box 存在
    if (!Hive.isBoxOpen(_courseBoxName(id))) {
      await Hive.openBox<Course>(_courseBoxName(id));
    }
    return id;
  }

  /// 激活指定学期（其余设为非激活）
  static Future<void> setActive(String id) async {
    for (final s in _box.values) {
      if (s.isActive != (s.id == id)) {
        s.isActive = (s.id == id);
        await s.save();
      }
    }
  }

  /// 重命名
  static Future<void> rename(String id, String newName) async {
    final s = _box.get(id);
    if (s != null) {
      s.name = newName;
      await s.save();
    }
  }

  /// 删除学期及其所有课程
  static Future<void> delete(String id) async {
    // 如果删的是激活学期，自动激活第一个剩余学期
    final s = _box.get(id);
    final wasActive = s?.isActive ?? false;

    await _box.delete(id);

    // 清空并关闭对应课程 box
    final boxName = _courseBoxName(id);
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<Course>(boxName).clear();
      await Hive.box<Course>(boxName).close();
    }
    await Hive.deleteBoxFromDisk(boxName);

    // 若删的是激活学期，激活剩余第一个
    if (wasActive && _box.isNotEmpty) {
      final first = _box.values.first;
      first.isActive = true;
      await first.save();
    }
  }

  // ── 课程操作（按学期）───────────────────────────────

  static Box<Course> _courseBox(String semesterId) =>
      Hive.box<Course>(_courseBoxName(semesterId));

  static String _courseBoxName(String semesterId) => 'courses_$semesterId';

  static List<Course> getCourses(String semesterId) =>
      _courseBox(semesterId).values.toList();

  static List<Course> getActiveCourses() {
    final active = getActive();
    if (active == null) return [];
    return getCourses(active.id);
  }

  static Future<void> addCourse(String semesterId, Course course) async =>
      _courseBox(semesterId).add(course);

  static Future<void> clearCourses(String semesterId) async =>
      _courseBox(semesterId).clear();

  /// 确保所有已存在学期的 course box 已打开（app 启动时调用）
  static Future<void> openAllCourseBoxes() async {
    for (final s in _box.values) {
      final name = _courseBoxName(s.id);
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<Course>(name);
      }
    }
  }
}
