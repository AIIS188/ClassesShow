import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'week_schedule_page.dart';
import '../services/semester_storage.dart';
import '../data/mock_timetable.dart';
import '../services/course_parser.dart';

/// 全局学期版本号，每次切换学期 +1，子页监听后刷新数据
final semesterVersion = ValueNotifier<int>(0);

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _initialized = false;
  late final List<Widget> _pages;

  static const _tabs = [
    _TabItem(icon: Icons.house_rounded,          outlineIcon: Icons.house_outlined,          label: '首页'),
    _TabItem(icon: Icons.calendar_month_rounded, outlineIcon: Icons.calendar_month_outlined, label: '课表'),
  ];

  @override
  void initState() {
    super.initState();
    _seedIfEmpty();
  }

  Future<void> _seedIfEmpty() async {
    final semesters = SemesterStorage.getAll();

    if (semesters.isEmpty) {
      final id = await SemesterStorage.create('默认1');
      final courses = CourseParser.parseCourses(mockKbList);
      for (final c in courses) {
        await SemesterStorage.addCourse(id, c);
      }
    }

    if (mounted) {
      _initPages();
      setState(() => _initialized = true);
    }
  }

  void _initPages() {
    _pages = [const HomePage(), const WeekSchedulePage()];
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _AppleTabBar(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) {
          HapticFeedback.lightImpact();
          setState(() => _currentIndex = i);
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// iOS 风格底部导航栏
// ════════════════════════════════════════════════════════
@immutable
class _TabItem {
  final IconData icon;
  final IconData outlineIcon;
  final String label;

  const _TabItem({
    required this.icon,
    required this.outlineIcon,
    required this.label,
  });
}

class _AppleTabBar extends StatelessWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onTap;

  const _AppleTabBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inactive = CupertinoInactiveColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xE5000000)  // ~90% 黑
              : const Color(0xF2F9F9F9), // ~95% 白
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.12),
              width: 0.4,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 50,
            child: Row(
              children: List.generate(tabs.length, (i) {
                final tab = tabs[i];
                final selected = i == currentIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 图标：选中放大 + 颜色切换
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: selected ? 1.1 : 1.0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Icon(
                            selected ? tab.icon : tab.outlineIcon,
                            size: 25,
                            color: selected ? primary : inactive,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // 文字
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: -0.2,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected ? primary : inactive,
                          ),
                          child: Text(tab.label),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

Color CupertinoInactiveColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF8E8E93)  // iOS dark 非选中色
      : const Color(0xFF8E8E93); // iOS light 非选中色（相同）
}