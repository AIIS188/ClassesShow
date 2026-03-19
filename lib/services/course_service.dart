import '../models/course.dart';

class CourseService {
  static List<Course> getTodayCourses(
      List<Course> allCourses, int week, int weekday) {
    return allCourses.where((course) {
      return course.weekday == weekday &&
          course.weeks.contains(week);
    }).toList();
  }
}