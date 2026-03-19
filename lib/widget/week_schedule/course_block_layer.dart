import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/course.dart';

// ─────────────────────────────────────────
// 课程配色池：按课程名哈希固定取色，
// 同一门课在不同周/位置颜色永远一致。
// ─────────────────────────────────────────
const List<List<Color>> _kCourseGradients = [
  [Color(0xFF6C8EFF), Color(0xFF4B6FFF)], // 蓝紫
  [Color(0xFFFF6B9D), Color(0xFFE0457A)], // 玫瑰
  [Color(0xFF43D9A2), Color(0xFF20B882)], // 青绿
  [Color(0xFFFFB347), Color(0xFFFF8C00)], // 橙
  [Color(0xFFA78BFA), Color(0xFF7C4DFF)], // 紫
  [Color(0xFF38BDF8), Color(0xFF0EA5E9)], // 天蓝
  [Color(0xFFF87171), Color(0xFFEF4444)], // 红
  [Color(0xFF34D399), Color(0xFF059669)], // 翠绿
  [Color(0xFFFBBF24), Color(0xFFD97706)], // 金黄
  [Color(0xFFE879F9), Color(0xFFC026D3)], // 粉紫
];

List<Color> _gradientFor(String name) {
  final idx =
      name.codeUnits.fold(0, (a, b) => a + b) % _kCourseGradients.length;
  return _kCourseGradients[idx];
}

// ─────────────────────────────────────────
// 单个课程块
// ─────────────────────────────────────────
class _CourseBlock extends StatelessWidget {
  final Course course;
  final bool isCurrentWeek;

  const _CourseBlock({
    required this.course,
    required this.isCurrentWeek,
  });

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourseDetailSheet(
        course: course,
        colors: _gradientFor(course.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradientFor(course.name);

    final List<Color> activeColors = isCurrentWeek
        ? [colors[0].withOpacity(0.45), colors[1].withOpacity(0.30)]
        : [
            const Color(0xFFBDBDBD).withOpacity(0.22),
            const Color(0xFF9E9E9E).withOpacity(0.14),
          ];

    final Color borderColor = isCurrentWeek
        ? colors[0].withOpacity(0.55)
        : Colors.white.withOpacity(0.20);

    final Color textColor = isCurrentWeek ? Colors.white : Colors.white60;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activeColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.0),
              boxShadow: isCurrentWeek
                  ? [
                      BoxShadow(
                        color: colors[1].withOpacity(0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // 课程名
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.25,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                // 地点
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 9,
                        color: textColor.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        course.location,
                        style: TextStyle(
                          fontSize: 9,
                          color: textColor.withOpacity(0.85),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ), // SingleChildScrollView
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────
// 点击展开：底部详情弹窗
// ─────────────────────────────────────────
class _CourseDetailSheet extends StatelessWidget {
  final Course course;
  final List<Color> colors;

  const _CourseDetailSheet({required this.course, required this.colors});

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors[0].withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: colors[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [1,2,3,5,10] → "1–3、5、10 周"
  String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '—';
    final sorted = [...weeks]..sort();
    final segments = <String>[];
    int start = sorted[0], end = sorted[0];
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == end + 1) {
        end = sorted[i];
      } else {
        segments.add(start == end ? '$start' : '$start–$end');
        start = end = sorted[i];
      }
    }
    segments.add(start == end ? '$start' : '$start–$end');
    return '${segments.join('、')} 周';
  }

  @override
  Widget build(BuildContext context) {
    final weekdayLabel =
        ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日']
            [course.weekday.clamp(1, 7)];
    final sectionLabel = course.startSection == course.endSection
        ? '第 ${course.startSection} 节'
        : '第 ${course.startSection}–${course.endSection} 节';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: colors[0].withOpacity(0.35), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 课程名 + 左侧色条
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 5,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      course.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 10),

              _infoRow(Icons.person_rounded, '教师', course.teacher),
              _infoRow(
                  Icons.location_on_rounded, '地点', course.location),
              _infoRow(Icons.access_time_rounded, '时间',
                  '$weekdayLabel　$sectionLabel'),
              _infoRow(Icons.calendar_month_rounded, '周次',
                  _formatWeeks(course.weeks)),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 对外接口（供 week_schedule_page 使用）
// ─────────────────────────────────────────

/// 课程块层：调用 [buildPositioned] 展开进 Stack，不可直接作为 Widget 使用。
class CourseBlockLayer {
  final List<Course> courses;
  final double columnWidth;
  final double cellHeight;
  final int displayWeek;

  const CourseBlockLayer({
    required this.courses,
    required this.columnWidth,
    required this.cellHeight,
    required this.displayWeek,
  });

  List<Positioned> buildPositioned() {
    return courses.map((c) {
      final int weekday = c.weekday.clamp(1, 7);
      final double left = (weekday - 1) * columnWidth;
      final double top = (c.startSection - 1) * cellHeight;
      final double blockHeight =
          (c.endSection - c.startSection + 1) * cellHeight;
      final bool isCurrentWeek = c.weeks.contains(displayWeek);

      return Positioned(
        left: left + 2,
        top: top + 2,
        width: columnWidth - 4,
        height: blockHeight - 4,
        child: _CourseBlock(
          course: c,
          isCurrentWeek: isCurrentWeek,
        ),
      );
    }).toList();
  }
}