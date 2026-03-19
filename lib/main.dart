import 'package:classes_show/pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/course.dart';
import 'models/semester.dart';  
import 'services/semester_storage.dart';
import 'services/migration_helper.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(CourseAdapter());
  Hive.registerAdapter(SemesterAdapter());       // 新增
  await Hive.openBox<Course>('courses');          // 旧 box，迁移用
  await Hive.openBox<Semester>('semesters');      // 新增
  await SemesterStorage.openAllCourseBoxes();    // 新增

  await MigrationHelper.runIfNeeded();           // 迁移旧数据，只跑一次

  runApp(const ClassesShowApp());
}

class ClassesShowApp extends StatelessWidget {
  const ClassesShowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classes Show',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

