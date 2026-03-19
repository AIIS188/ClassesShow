import 'package:flutter/material.dart';

/// 顶部日期栏：左侧月份 + 右侧7列（星期 + 日期）
class WeekHeader extends StatelessWidget {
  final List<DateTime> weekDays;
  final DateTime currentDate;

  const WeekHeader({
    super.key,
    required this.weekDays,
    required this.currentDate,
  });

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        /// 左上角：月份
        SizedBox(
          width: 60,
          child: Center(
            child: Text(
              "${currentDate.month}月",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        /// 7列：星期 + 日期
        Expanded(
          child: Row(
            children: List.generate(7, (index) {
              DateTime d = weekDays[index];
              bool isToday = _isSameDay(d, DateTime.now());

              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: isToday ? Colors.blue.withOpacity(0.1) : null,
                  ),
                  child: Column(
                    children: [
                      Text(["一", "二", "三", "四", "五", "六", "日"][index]),
                      Text(
                        "${d.day}",
                        style: TextStyle(
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
