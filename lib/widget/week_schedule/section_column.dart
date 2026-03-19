import 'package:flutter/material.dart';
import '../../models/section_time.dart';

/// 左侧节次轴：显示节次编号和时间段，点击可进入时间设置
class SectionColumn extends StatelessWidget {
  final int sectionCount;
  final double cellHeight;
  final List<SectionTime> sectionTimes; // 真实时间表
  final VoidCallback? onTap;           // 点击进入设置

  const SectionColumn({
    super.key,
    required this.sectionCount,
    required this.cellHeight,
    this.sectionTimes = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: List.generate(sectionCount, (index) {
          // 优先用真实时间，不足则 fallback 到占位
          final hasTime = index < sectionTimes.length;
          final t = hasTime ? sectionTimes[index] : null;

          return Container(
            height: cellHeight,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t?.startLabel ?? '--:--',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  t?.endLabel ?? '--:--',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
