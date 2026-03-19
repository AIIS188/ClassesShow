import '../models/course.dart';

class CourseParser {
  ///主入口：解析整个kblist
  static List<Course> parseCourses(List<dynamic> kbList) {
    return kbList.map((e) => parseCourse(e)).toList();
  }
  /// 单条课程解析
static Course parseCourse(Map json) {
  // 节次
  List<String> sections = json['jcs'].toString().split('-');
  int start = int.parse(sections[0]);
  int end = int.parse(sections[1]);

  // 周次
  List<int> weeks = parseWeeks(json['zcd'].toString());

  return Course(
    name: json['kcmc'].toString(),
    weekday: int.parse(json['xqj'].toString()),
    startSection: start,
    endSection: end,
    location: json['cdmc'].toString(),
    teacher: json['xm'].toString(),
    weeks: weeks,
  );
}
  /// 解析 "1-13周,16-17周"
  static List<int> parseWeeks(String zcd) {
    List<int> result = [];

    var parts = zcd.replaceAll('周', '').split(',');

    for (var part in parts) {
      if (part.contains('-')) {
        var range = part.split('-');
        int start = int.parse(range[0]);
        int end = int.parse(range[1]);

        for (int i = start; i <= end; i++) {
          result.add(i);
        }
      } else {
        result.add(int.parse(part));
      }
    }

    return result;
  }
}