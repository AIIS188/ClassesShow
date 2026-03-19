import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/section_time.dart';
import '../services/course_service.dart';
import '../services/schedule_settings.dart';
import '../services/section_time_storage.dart';
import '../utils/week_utils.dart';
import '../widget/home/week_bar.dart';
import '../widget/home/course_card.dart';
import '../services/semester_storage.dart';
import 'main_page.dart' show semesterVersion;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Course> _allCourses = [];
  List<Course> _todayCourses = [];
  List<SectionTime> _sectionTimes = [];
  int _selectedWeekday = DateTime.now().weekday;
  int _currentWeek = 1;
  Timer? _ticker; // 每分钟刷新一次卡片状态

  @override
  void initState() {
    super.initState();
    _allCourses = SemesterStorage.getActiveCourses(); // 同步读取，立即有数据
    _updateCourses();
    _loadSettings();
    _loadSectionTimes();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    semesterVersion.addListener(_onSemesterChanged);
  }

  void _onSemesterChanged() {
    if (!mounted) return;
    setState(() {
      _allCourses = SemesterStorage.getActiveCourses();
      _updateCourses();
    });
  }

  // IndexedStack 切换回首页时会调用此方法，趁机重新读取课程
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadCourses();
  }

  void _reloadCourses() {
    setState(() {
      _allCourses = SemesterStorage.getActiveCourses();
      _updateCourses();
    });
  }

  Future<void> _loadSectionTimes() async {
    final times = await SectionTimeStorage.loadTimes();
    if (mounted) setState(() => _sectionTimes = times);
  }

  @override
  void dispose() {
    semesterVersion.removeListener(_onSemesterChanged);
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await ScheduleSettings.load();
    if (!mounted) return;
    final semesterStart = s['semesterStart'] as DateTime;
    setState(() {
      _currentWeek = calcCurrentWeek(semesterStart);
      _updateCourses();
    });
  }

  void _updateCourses() {
    _todayCourses = CourseService.getTodayCourses(
      _allCourses,
      _currentWeek,
      _selectedWeekday,
    );
  }

  bool get _isToday => _selectedWeekday == DateTime.now().weekday;

  void _backToToday() {
    setState(() {
      _selectedWeekday = DateTime.now().weekday;
      _updateCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: _isToday ? null : _backToToday,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('今日课程  第 $_currentWeek 周'),
              if (!_isToday) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '回今天',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          WeekBar(
            selectedWeekday: _selectedWeekday,
            onDaySelected: (day) {
              setState(() {
                _selectedWeekday = day;
                _updateCourses();
              });
            },
          ),
          Expanded(
            child: _todayCourses.isEmpty
                ? const Center(child: Text('今天没课 😎'))
                : Stack(
                    children: [
                      ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _todayCourses.length,
                        itemBuilder: (context, index) {
                          return CourseCard(
                            c: _todayCourses[index],
                            index: index,
                            sectionTimes: _sectionTimes,
                          );
                        },
                      ),
                      // 顶部渐隐遮罩
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).scaffoldBackgroundColor,
                                Theme.of(context)
                                    .scaffoldBackgroundColor
                                    .withOpacity(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}