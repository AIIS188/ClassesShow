import 'package:classes_show/pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/course.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();                  // 初始化 Hive
  Hive.registerAdapter(CourseAdapter());     // 注册生成的 Adapter
  await Hive.openBox<Course>('courses');     // 打开 box

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

