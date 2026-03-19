import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/section_time.dart';

class SectionTimeStorage {
  static const _keyTimes         = 'section_times';
  static const _keyClassDuration = 'section_class_duration';
  static const _keyBreakDuration = 'section_break_duration';

  // ── 节次列表 ──────────────────────────────────────
  static Future<List<SectionTime>> loadTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTimes);
    if (raw == null) return List<SectionTime>.from(defaultSectionTimes());
    return (jsonDecode(raw) as List)
        .map((e) => SectionTime.fromMap(e as Map))
        .toList();
  }

  static Future<void> saveTimes(List<SectionTime> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTimes,
      jsonEncode(times.map((e) => e.toMap()).toList()),
    );
  }

  // ── 课时长 & 休息时长 ─────────────────────────────
  static Future<int> loadClassDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyClassDuration) ?? 45;
  }

  static Future<int> loadBreakDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyBreakDuration) ?? 5;
  }

  static Future<void> saveClassDuration(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyClassDuration, v);
  }

  static Future<void> saveBreakDuration(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyBreakDuration, v);
  }

  // ── 一次性保存所有配置 ────────────────────────────
  static Future<void> saveAll({
    required List<SectionTime> times,
    required int classDuration,
    required int breakDuration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(
          _keyTimes, jsonEncode(times.map((e) => e.toMap()).toList())),
      prefs.setInt(_keyClassDuration, classDuration),
      prefs.setInt(_keyBreakDuration, breakDuration),
    ]);
  }
}