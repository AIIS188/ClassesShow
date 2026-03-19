import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../models/section_time.dart';
import '../services/course_storage.dart';
import '../services/section_time_storage.dart';
import '../widget/week_schedule/week_header.dart';
import '../widget/week_schedule/section_column.dart';
import '../widget/week_schedule/background_grid.dart';
import '../widget/week_schedule/course_block_layer.dart';
import 'add_course_page.dart';
import 'section_time_setting_page.dart';
import '../services/schedule_settings.dart';
import '../utils/week_utils.dart';
import 'import_schedule_page.dart';

class WeekSchedulePage extends StatefulWidget {
  const WeekSchedulePage({super.key});

  @override
  State<WeekSchedulePage> createState() => _WeekSchedulePageState();
}

class _WeekSchedulePageState extends State<WeekSchedulePage> {
  // ── 课表核心状态 ──────────────────────────
  int sectionCount = 15;
  late PageController _pageController;

  // page=1000 对应本周（offset=0），左右滑动代表 offset
  static const int _basePage = 1000;
  int _currentPage = _basePage;

  // ── 当前周计算 ────────────────────────────
  // 本周周次（由开学日期决定），页面偏移后得到显示周次
  int _todayWeek = 1;

  int get _displayWeek => _todayWeek + (_currentPage - _basePage);

  /// 当前显示的周对应的 offset 是否是本周
  bool get _isThisWeek => _currentPage == _basePage;

  /// 跳回本周
  void _jumpToThisWeek() {
    _pageController.animateToPage(
      _basePage,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ── 课程数据（从 Hive 读取）──────────────
  List<Course> _courses = [];
  void _refresh() => setState(() => _courses = CourseStorage.getCourses());

  // ── 节次时间表 ────────────────────────────
  List<SectionTime> _sectionTimes = [];

  // ── 设置状态 ─────────────────────────────
  TimeOfDay _firstClassTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime _semesterStartDate = DateTime(2025, 2, 24);
  int _startWeekday = DateTime.monday;
  bool _showNonCurrentWeek = true;

  // ── Overlay 控制 ──────────────────────────
  final LayerLink _settingsLink = LayerLink();
  final LayerLink _functionsLink = LayerLink();
  OverlayEntry? _settingsOverlay;
  OverlayEntry? _functionsOverlay;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _basePage);
    _courses = CourseStorage.getCourses();
    _loadSettings();
    _loadSectionTimes();
  }

  Future<void> _loadSettings() async {
    final s = await ScheduleSettings.load();
    if (!mounted) return;
    setState(() {
      _semesterStartDate  = s['semesterStart'] as DateTime;
      _firstClassTime     = s['firstClassTime'] as TimeOfDay;
      sectionCount        = s['sectionCount'] as int;
      _startWeekday       = s['startWeekday'] as int;
      _showNonCurrentWeek = s['showNonCurrent'] as bool;
      _todayWeek = calcCurrentWeek(_semesterStartDate);
    });
  }

  Future<void> _loadSectionTimes() async {
    final times = await SectionTimeStorage.loadTimes();
    if (mounted) setState(() => _sectionTimes = times);
  }

  Future<void> _openSectionTimeSetting() async {
    final result = await Navigator.push<List<SectionTime>>(
      context,
      MaterialPageRoute(
          builder: (_) => const SectionTimeSettingPage()),
    );
    if (result != null && mounted) {
      setState(() => _sectionTimes = result);
    }
  }

  @override
  void dispose() {
    _removeOverlay(_settingsOverlay);
    _removeOverlay(_functionsOverlay);
    super.dispose();
  }

  void _removeOverlay(OverlayEntry? entry) {
    entry?.remove();
  }

  void _closeAll() {
    _settingsOverlay?.remove();
    _settingsOverlay = null;
    _functionsOverlay?.remove();
    _functionsOverlay = null;
  }

  // ════════════════════════════════════════
  // 设置菜单 Overlay
  // ════════════════════════════════════════
  void _toggleSettings() {
    if (_settingsOverlay != null) {
      _closeAll();
      return;
    }
    _closeAll();

    _settingsOverlay = _buildSettingsOverlay();
    Overlay.of(context).insert(_settingsOverlay!);
  }

  OverlayEntry _buildSettingsOverlay() {
    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 遮罩：点击菜单外部关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeAll,
            ),
          ),
          // 菜单卡片：吸收自身区域点击，不让遮罩收到
          CompositedTransformFollower(
            link: _settingsLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _PopupCard(
                width: 260,
                child: _SettingsContent(
                  semesterStartDate: _semesterStartDate,
                  sectionCount: sectionCount,
                  startWeekday: _startWeekday,
                  showNonCurrentWeek: _showNonCurrentWeek,
                  onSemesterStartDateTap: () async {
                    final p = await showDatePicker(
                      context: context,
                      initialDate: _semesterStartDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (p != null && mounted) {
                      setState(() {
                        _semesterStartDate = p;
                        _todayWeek = calcCurrentWeek(p);
                      });
                      await ScheduleSettings.saveSemesterStart(p);
                      _jumpToThisWeek();
                    }
                  },
                  onSectionCountChanged: (n) {
                    setState(() => sectionCount = n);
                    ScheduleSettings.saveSectionCount(n);
                  },
                  onStartWeekdayChanged: (d) {
                    setState(() => _startWeekday = d);
                    ScheduleSettings.saveStartWeekday(d);
                  },
                  onShowNonCurrentWeekChanged: (v) {
                    setState(() => _showNonCurrentWeek = v);
                    ScheduleSettings.saveShowNonCurrent(v);
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // 功能菜单 Overlay
  // ════════════════════════════════════════
  void _toggleFunctions() {
    if (_functionsOverlay != null) {
      _closeAll();
      return;
    }
    _closeAll();

    _functionsOverlay = _buildFunctionsOverlay();
    Overlay.of(context).insert(_functionsOverlay!);
  }

  OverlayEntry _buildFunctionsOverlay() {
    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          // 遮罩：点击菜单外部关闭
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // opaque：吞掉点击，不穿透
              onTap: _closeAll,
            ),
          ),
          // 菜单卡片：吸收自身区域的点击，不让遮罩收到
          CompositedTransformFollower(
            link: _functionsLink,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // 吸收点击，不下传遮罩
              onTap: () {}, // 消费点击事件
              child: _PopupCard(
                width: 200,
                child: _FunctionsContent(
                  onSectionTimeSetting: () async {
                    _closeAll();
                    final result = await Navigator.push<List<SectionTime>>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SectionTimeSettingPage()),
                    );
                    if (result != null && mounted) {
                      setState(() => _sectionTimes = result);
                    }
                  },
                  onSwitchSemester: () {
                    _closeAll();
                    // TODO: 跳转学期切换页
                  },
                  onImportSchedule: () async {
                    _closeAll();
                    final imported = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ImportSchedulePage()),
                    );
                    if (imported == true && mounted) _refresh();
                  },
                  onAddCourse: () async {
                    _closeAll();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddCoursePage()),
                    );
                    _refresh();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onTap: _isThisWeek ? null : _jumpToThisWeek,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('第 $_displayWeek 周'),
              if (!_isThisWeek) ...[
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
                    '回本周',
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
        leading: CompositedTransformTarget(
          link: _settingsLink,
          child: IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '课表设置',
            onPressed: _toggleSettings,
          ),
        ),
        actions: [
          CompositedTransformTarget(
            link: _functionsLink,
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: '功能',
              onPressed: _toggleFunctions,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          WeekHeader(
            weekDays: _getWeekByOffset(_currentPage - _basePage),
            currentDate: DateTime.now().add(
                Duration(days: 7 * (_currentPage - _basePage))),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                _closeAll();
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) => _buildWeekView(index),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // 周视图
  // ════════════════════════════════════════
  Widget _buildWeekView(int index) {
    final int weekOffset = index - 1000;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellHeight =
            (MediaQuery.of(context).size.height * 0.1).clamp(70, 110);
        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: SectionColumn(
                  sectionCount: sectionCount,
                  cellHeight: cellHeight,
                  sectionTimes: _sectionTimes,
                  onTap: _openSectionTimeSetting,
                ),
              ),
              Expanded(
                  child: _buildGridWithCourses(cellHeight, weekOffset)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridWithCourses(double cellHeight, int weekOffset) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double columnWidth = constraints.maxWidth / 7;
        final int displayWeek = _todayWeek + weekOffset;
        final courses = _showNonCurrentWeek
            ? _courses
            : _courses
                .where((c) => c.weeks.contains(displayWeek))
                .toList();
        return Stack(
          children: [
            BackgroundGrid(
              sectionCount: sectionCount,
              columnWidth: columnWidth,
              cellHeight: cellHeight,
            ),
            ...CourseBlockLayer(
              courses: courses,
              columnWidth: columnWidth,
              cellHeight: cellHeight,
              displayWeek: displayWeek,
            ).buildPositioned(),
          ],
        );
      },
    );
  }

  List<DateTime> _getWeekByOffset(int offset) {
    final base = DateTime.now().add(Duration(days: 7 * offset));
    final monday = base.subtract(Duration(days: base.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }
}

// ════════════════════════════════════════════════════════
// 弹出卡片容器（毛玻璃 + 阴影 + 圆角）
// ════════════════════════════════════════════════════════
class _PopupCard extends StatelessWidget {
  final double width;
  final Widget child;

  const _PopupCard({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 设置菜单内容
// ════════════════════════════════════════════════════════
class _SettingsContent extends StatefulWidget {
  final DateTime semesterStartDate;
  final int sectionCount;
  final int startWeekday;
  final bool showNonCurrentWeek;
  final VoidCallback onSemesterStartDateTap;
  final ValueChanged<int> onSectionCountChanged;
  final ValueChanged<int> onStartWeekdayChanged;
  final ValueChanged<bool> onShowNonCurrentWeekChanged;

  const _SettingsContent({
    required this.semesterStartDate,
    required this.sectionCount,
    required this.startWeekday,
    required this.showNonCurrentWeek,
    required this.onSemesterStartDateTap,
    required this.onSectionCountChanged,
    required this.onStartWeekdayChanged,
    required this.onShowNonCurrentWeekChanged,
  });

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late int _sections;
  late int _startDay;
  late bool _showAll;

  @override
  void initState() {
    super.initState();
    _sections = widget.sectionCount;
    _startDay = widget.startWeekday;
    _showAll  = widget.showNonCurrentWeek;
  }

  @override
  void didUpdateWidget(_SettingsContent old) {
    super.didUpdateWidget(old);
    if (old.sectionCount       != widget.sectionCount)       _sections = widget.sectionCount;
    if (old.startWeekday       != widget.startWeekday)       _startDay = widget.startWeekday;
    if (old.showNonCurrentWeek != widget.showNonCurrentWeek) _showAll  = widget.showNonCurrentWeek;
  }

  String get _dateLabel {
    final d = widget.semesterStartDate;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupLabel('课表设置'),
          _PopupTile(
            icon: Icons.calendar_today_rounded,
            label: '开学日期',
            value: _dateLabel,
            onTap: widget.onSemesterStartDateTap,
          ),
          _Divider(),
          _GroupLabel('通用设置'),
          // 节数：行内 +/- 控件
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _iconBox(Icons.format_list_numbered_rounded, context),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('节数',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                _StepperBtn(
                  value: _sections,
                  min: 1,
                  max: 20,
                  onChanged: (v) {
                    setState(() => _sections = v);
                    widget.onSectionCountChanged(v);
                  },
                ),
              ],
            ),
          ),
          // 每周起始日
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                _iconBox(Icons.view_week_rounded, context),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('起始日',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                _SegmentedPicker<int>(
                  value: _startDay,
                  options: const [
                    _SegOption(value: DateTime.monday, label: '周一'),
                    _SegOption(value: DateTime.sunday, label: '周日'),
                  ],
                  onChanged: (v) {
                    setState(() => _startDay = v);
                    widget.onStartWeekdayChanged(v);
                  },
                ),
              ],
            ),
          ),
          // 显示非本周
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                _iconBox(Icons.visibility_rounded, context),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('显示非本周',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: _showAll,
                    onChanged: (v) {
                      setState(() => _showAll = v);
                      widget.onShowNonCurrentWeekChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon, BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon,
          size: 15, color: Theme.of(context).colorScheme.primary),
    );
  }
}

// ════════════════════════════════════════════════════════
// 功能菜单内容
// ════════════════════════════════════════════════════════
class _FunctionsContent extends StatelessWidget {
  final VoidCallback onSectionTimeSetting;
  final VoidCallback onSwitchSemester;
  final VoidCallback onImportSchedule;
  final VoidCallback onAddCourse;

  const _FunctionsContent({
    required this.onSectionTimeSetting,
    required this.onSwitchSemester,
    required this.onImportSchedule,
    required this.onAddCourse,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PopupTile(
            icon: Icons.schedule_rounded,
            label: '节次时间设置',
            onTap: onSectionTimeSetting,
          ),
          _PopupTile(
            icon: Icons.swap_horiz_rounded,
            label: '切换学期',
            onTap: onSwitchSemester,
          ),
          _PopupTile(
            icon: Icons.file_download_outlined,
            label: '导入课表',
            onTap: onImportSchedule,
          ),
          _PopupTile(
            icon: Icons.add_circle_outline_rounded,
            label: '手动添加课程',
            onTap: onAddCourse,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 弹出菜单通用行
// ════════════════════════════════════════════════════════
class _PopupTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _PopupTile({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 6),
              Text(value!,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.grey.shade400),
            ] else
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 小组件
// ════════════════════════════════════════════════════════

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade400,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }
}

// +/- 步进器
class _StepperBtn extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperBtn({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(
          icon: Icons.remove,
          active: value > min,
          color: primary,
          onTap: () { if (value > min) onChanged(value - 1); },
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _Btn(
          icon: Icons.add,
          active: value < max,
          color: primary,
          onTap: () { if (value < max) onChanged(value + 1); },
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Btn(
      {required this.icon,
      required this.active,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 13,
            color: active ? color : Colors.grey.shade300),
      ),
    );
  }
}

// 分段选择器
class _SegOption<T> {
  final T value;
  final String label;
  const _SegOption({required this.value, required this.label});
}

class _SegmentedPicker<T> extends StatelessWidget {
  final T value;
  final List<_SegOption<T>> options;
  final ValueChanged<T> onChanged;

  const _SegmentedPicker({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = opt.value == value;
          return GestureDetector(
            onTap: () => onChanged(opt.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}