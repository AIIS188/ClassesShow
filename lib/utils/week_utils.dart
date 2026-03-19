/// 根据开学日期计算今天是第几教学周（1-based）。
///
/// 规则：开学日期所在自然周为第1周，无论开学日期是周几。
/// 若今天早于开学周，返回 1。
int calcCurrentWeek(DateTime semesterStart) {
  // 开学日期所在周的周一（ISO weekday: 1=周一 … 7=周日）
  final semesterMonday =
      semesterStart.subtract(Duration(days: semesterStart.weekday - 1));

  // 今天所在周的周一
  final today = DateTime.now();
  final todayMonday =
      today.subtract(Duration(days: today.weekday - 1));

  // 两个周一之差 ÷ 7 = 周偏移
  final diffDays = todayMonday
      .difference(semesterMonday)
      .inDays;

  return (diffDays ~/ 7 + 1).clamp(1, 99);
}