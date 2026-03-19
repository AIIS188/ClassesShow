import 'package:flutter/material.dart';

/// 课表背景网格：sectionCount 行 × 7 列
class BackgroundGrid extends StatelessWidget {
  final int sectionCount;
  final double columnWidth;
  final double cellHeight;

  const BackgroundGrid({
    super.key,
    required this.sectionCount,
    required this.columnWidth,
    required this.cellHeight,
  });

  @override
  Widget build(BuildContext context) {
    // 交替行背景色，毛玻璃才有内容可模糊
    const Color rowA = Color(0xFFF3F6FF);
    const Color rowB = Color(0xFFEEF2FF);

    return Column(
      children: List.generate(sectionCount, (row) {
        return Row(
          children: List.generate(7, (col) {
            return Container(
              width: columnWidth,
              height: cellHeight,
              decoration: BoxDecoration(
                color: row.isEven ? rowA : rowB,
                border: Border(
                  right: BorderSide(color: Colors.indigo.withOpacity(0.08)),
                  bottom: BorderSide(color: Colors.indigo.withOpacity(0.08)),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}