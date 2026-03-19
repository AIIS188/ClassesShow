import 'package:flutter/material.dart';

class WeekBar extends StatelessWidget {
  final int selectedWeekday;
  final Function(int) onDaySelected;

  const WeekBar({
    super.key,
    required this.selectedWeekday,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    List<String> days = ["一", "二", "三", "四", "五", "六", "日"];

    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;

        return Row(
          children: List.generate(7, (index) {
            int day = index + 1;
            bool isSelected = day == selectedWeekday;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  onDaySelected(day); // ✅ 用回调！
                },
                child: AspectRatio(
                  aspectRatio: 1.8,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "周${days[index]}",
                      style: TextStyle(
                        fontSize: width * 0.035,
                        color:
                            isSelected ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}