/// 单节课的时间信息
class SectionTime {
  final int section;      // 第几节（1-based）
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  const SectionTime({
    required this.section,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  String get startLabel =>
      '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
  String get endLabel =>
      '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

  /// 本节上课时长（分钟）
  int get durationMinutes =>
      endHour * 60 + endMinute - startHour * 60 - startMinute;

  /// 与下一节之间的休息时长（分钟）
  int breakBefore(SectionTime next) =>
      next.startHour * 60 + next.startMinute - endHour * 60 - endMinute;

  /// 从上一节结束时间 + 课时长 + 休息长 计算下一节
  factory SectionTime.fromPrev({
    required int section,
    required SectionTime prev,
    required int classDuration,   // 分钟
    required int breakDuration,   // 分钟
  }) {
    int totalMinutes =
        prev.endHour * 60 + prev.endMinute + breakDuration;
    int sh = totalMinutes ~/ 60;
    int sm = totalMinutes % 60;
    int totalEnd = sh * 60 + sm + classDuration;
    return SectionTime(
      section: section,
      startHour: sh,
      startMinute: sm,
      endHour: totalEnd ~/ 60,
      endMinute: totalEnd % 60,
    );
  }

  SectionTime copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return SectionTime(
      section: section,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  Map<String, int> toMap() => {
        'section': section,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
      };

  factory SectionTime.fromMap(Map map) => SectionTime(
        section: map['section'] as int,
        startHour: map['startHour'] as int,
        startMinute: map['startMinute'] as int,
        endHour: map['endHour'] as int,
        endMinute: map['endMinute'] as int,
      );
}

/// 默认节次表（11节，常见高校时间）
List<SectionTime> defaultSectionTimes() {
  return [
    SectionTime(section: 1,  startHour: 8,  startMinute: 0,  endHour: 8,  endMinute: 45),
    SectionTime(section: 2,  startHour: 8,  startMinute: 50, endHour: 9,  endMinute: 35),
    SectionTime(section: 3,  startHour: 10, startMinute: 0,  endHour: 10, endMinute: 45),
    SectionTime(section: 4,  startHour: 10, startMinute: 50, endHour: 11, endMinute: 35),
    SectionTime(section: 5,  startHour: 13, startMinute: 30, endHour: 14, endMinute: 15),
    SectionTime(section: 6,  startHour: 14, startMinute: 20, endHour: 15, endMinute: 5),
    SectionTime(section: 7,  startHour: 15, startMinute: 15, endHour: 16, endMinute: 0),
    SectionTime(section: 8,  startHour: 16, startMinute: 5,  endHour: 16, endMinute: 50),
    SectionTime(section: 9,  startHour: 18, startMinute: 0,  endHour: 18, endMinute: 45),
    SectionTime(section: 10, startHour: 18, startMinute: 50, endHour: 19, endMinute: 35),
    SectionTime(section: 11, startHour: 19, startMinute: 40, endHour: 20, endMinute: 25),
  ];
}