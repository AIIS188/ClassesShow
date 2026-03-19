import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../models/section_time.dart';

// 与 course_block_layer 保持一致的配色池
const List<List<Color>> _kGradients = [
  [Color(0xFF6C8EFF), Color(0xFF4B6FFF)],
  [Color(0xFFFF6B9D), Color(0xFFE0457A)],
  [Color(0xFF43D9A2), Color(0xFF20B882)],
  [Color(0xFFFFB347), Color(0xFFFF8C00)],
  [Color(0xFFA78BFA), Color(0xFF7C4DFF)],
  [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
  [Color(0xFFF87171), Color(0xFFEF4444)],
  [Color(0xFF34D399), Color(0xFF059669)],
  [Color(0xFFFBBF24), Color(0xFFD97706)],
  [Color(0xFFE879F9), Color(0xFFC026D3)],
];

List<Color> _colorsFor(String name) {
  final idx = name.codeUnits.fold(0, (a, b) => a + b) % _kGradients.length;
  return _kGradients[idx];
}

// ── 课程状态 ──────────────────────────────────────────
enum _CourseStatus { upcoming, ongoing, finished }

_CourseStatus _getStatus(
    Course c, List<SectionTime> sectionTimes, DateTime now) {
  // 找开始节和结束节对应的时间
  SectionTime? start = _sectionAt(c.startSection, sectionTimes);
  SectionTime? end   = _sectionAt(c.endSection,   sectionTimes);
  if (start == null || end == null) return _CourseStatus.upcoming;

  final startMin = start.startHour * 60 + start.startMinute;
  final endMin   = end.endHour * 60   + end.endMinute;
  final nowMin   = now.hour * 60      + now.minute;

  if (nowMin < startMin)  return _CourseStatus.upcoming;
  if (nowMin >= endMin)   return _CourseStatus.finished;
  return _CourseStatus.ongoing;
}

SectionTime? _sectionAt(int section, List<SectionTime> times) {
  try {
    return times.firstWhere((t) => t.section == section);
  } catch (_) {
    return null;
  }
}

String _timeRange(Course c, List<SectionTime> sectionTimes) {
  final start = _sectionAt(c.startSection, sectionTimes);
  final end   = _sectionAt(c.endSection,   sectionTimes);
  if (start == null || end == null) {
    return '第 ${c.startSection}–${c.endSection} 节';
  }
  return '${start.startLabel} – ${end.endLabel}';
}

// ════════════════════════════════════════════════════════
// CourseCard
// ════════════════════════════════════════════════════════
class CourseCard extends StatelessWidget {
  final Course c;
  final int index;
  final List<SectionTime> sectionTimes;

  const CourseCard({
    super.key,
    required this.c,
    required this.index,
    this.sectionTimes = const [],
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(c.name),
      duration: Duration(milliseconds: 280 + index * 50),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
      child: _CardContent(c: c, sectionTimes: sectionTimes),
    );
  }
}

class _CardContent extends StatelessWidget {
  final Course c;
  final List<SectionTime> sectionTimes;

  const _CardContent({required this.c, required this.sectionTimes});

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final status = _getStatus(c, sectionTimes, now);
    final colors = _colorsFor(c.name);
    final w      = MediaQuery.of(context).size.width;

    // 已结束：灰色毛玻璃；进行中：彩色实体；待上：彩色半透明毛玻璃
    final isFinished = status == _CourseStatus.finished;
    final isOngoing  = status == _CourseStatus.ongoing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: w * 0.018),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: isFinished
              ? ImageFilter.blur(sigmaX: 8, sigmaY: 8)
              : ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: isFinished
                  ? LinearGradient(colors: [
                      Colors.grey.shade300.withOpacity(0.45),
                      Colors.grey.shade200.withOpacity(0.30),
                    ])
                  : LinearGradient(
                      colors: [
                        colors[0].withOpacity(isOngoing ? 0.85 : 0.45),
                        colors[1].withOpacity(isOngoing ? 0.70 : 0.28),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: isFinished
                    ? Colors.white.withOpacity(0.25)
                    : isOngoing
                        ? colors[0].withOpacity(0.6)
                        : Colors.white.withOpacity(0.45),
                width: 1,
              ),
              boxShadow: isFinished
                  ? []
                  : [
                      BoxShadow(
                        color: colors[1].withOpacity(isOngoing ? 0.28 : 0.14),
                        blurRadius: isOngoing ? 16 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧色条
                Container(
                  width: 4,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isFinished
                        ? Colors.grey.shade400
                        : isOngoing
                            ? colors[0]
                            : colors[0].withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 14),

                // 主内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 课程名 + 状态标签
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: w * 0.046,
                                fontWeight: FontWeight.w700,
                                color: isFinished
                                    ? Colors.grey.shade500
                                    : Colors.white,
                                shadows: isFinished
                                    ? []
                                    : [
                                        Shadow(
                                          color:
                                              Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                        )
                                      ],
                              ),
                            ),
                          ),
                          _StatusBadge(status: status, colors: colors),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 时间
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        text: _timeRange(c, sectionTimes),
                        finished: isFinished,
                        color: colors[0],
                      ),
                      const SizedBox(height: 4),

                      // 地点
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        text: c.location,
                        finished: isFinished,
                        color: colors[0],
                      ),
                      const SizedBox(height: 4),

                      // 教师
                      _InfoRow(
                        icon: Icons.person_rounded,
                        text: c.teacher,
                        finished: isFinished,
                        color: colors[0],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 状态标签 ─────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final _CourseStatus status;
  final List<Color> colors;

  const _StatusBadge({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _CourseStatus.ongoing:
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.5), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '上课中',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      case _CourseStatus.finished:
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '已结束',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        );
      case _CourseStatus.upcoming:
        return const SizedBox.shrink();
    }
  }
}

// ── 信息行 ───────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool finished;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.finished,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = finished ? Colors.grey.shade500 : Colors.white70;
    final iconColor = finished ? Colors.grey.shade400 : color.withOpacity(0.9);

    return Row(
      children: [
        Icon(icon, size: 13, color: iconColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}