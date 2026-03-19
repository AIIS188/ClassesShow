import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 课表页通用设置的持久化（SharedPreferences）
class ScheduleSettings {
  static const _keySemesterStart  = 'semester_start';   // int，毫秒时间戳
  static const _keyFirstClassH    = 'first_class_h';
  static const _keyFirstClassM    = 'first_class_m';
  static const _keySectionCount   = 'section_count';
  static const _keyStartWeekday   = 'start_weekday';
  static const _keyShowNonCurrent = 'show_non_current';

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'semesterStart': prefs.containsKey(_keySemesterStart)
          ? DateTime.fromMillisecondsSinceEpoch(
              prefs.getInt(_keySemesterStart)!)
          : DateTime(DateTime.now().year, 9, 1), // 默认当年9月1日
      'firstClassTime': TimeOfDay(
        hour:   prefs.getInt(_keyFirstClassH) ?? 8,
        minute: prefs.getInt(_keyFirstClassM) ?? 0,
      ),
      'sectionCount':   prefs.getInt(_keySectionCount)   ?? 15,
      'startWeekday':   prefs.getInt(_keyStartWeekday)   ?? DateTime.monday,
      'showNonCurrent': prefs.getBool(_keyShowNonCurrent) ?? true,
    };
  }

  static Future<void> saveSemesterStart(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySemesterStart, d.millisecondsSinceEpoch);
  }

  static Future<void> saveFirstClassTime(TimeOfDay t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyFirstClassH, t.hour);
    await prefs.setInt(_keyFirstClassM, t.minute);
  }

  static Future<void> saveSectionCount(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySectionCount, v);
  }

  static Future<void> saveStartWeekday(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStartWeekday, v);
  }

  static Future<void> saveShowNonCurrent(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowNonCurrent, v);
  }
}