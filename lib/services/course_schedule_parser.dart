import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/course.dart';

/// 课表解析服务 - 使用阿里云百炼 Coding Plan API（OpenAI 兼容协议）
///
///   Coding Plan： baseUrl = https://coding.dashscope.aliyuncs.com/v1
///                 apiKey  = sk-sp-xxxxx（在百炼控制台 Coding Plan 页面获取）
///   普通按量付费：baseUrl = https://dashscope.aliyuncs.com/compatible-mode/v1
///                 apiKey  = sk-xxxxx
class CourseScheduleParser {
  static const _apiKey  = 'sk-sp-85d22a3083934e79850cba43520cc569'; // sk-sp-xxxxx
  static const _baseUrl = 'https://coding.dashscope.aliyuncs.com/v1';
  // static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1'; // 按量付费

  static const _model = 'qwen3.5-plus'; // 或 qwen-max 获得更高准确率

  static const _systemPrompt =
      '你是一个专业的课程表解析助手，擅长从各种格式的课表中提取结构化信息。';

  static const _userPrompt = '''
请从以下课表内容中提取所有课程信息，返回纯 JSON 数组。

规则：
- 只返回 JSON，不加任何说明文字或 markdown 代码块
- weekday: 1=周一 … 7=周日
- startSection / endSection: 第几节课（整数）
- weeks: 上课周次整数数组；若不明确填 [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
- location / teacher 无信息则填空字符串
- 同一门课不同时间段分开列，不要合并

输出格式：
[{"name":"高等数学","weekday":1,"startSection":1,"endSection":2,"location":"A101","teacher":"张三","weeks":[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]}]

课表内容：
''';

  // ── 从网页 HTML 解析 ─────────────────────────────
  // html 已经由 JS 在 WebView 侧清理过，直接发送
  static Future<List<Course>> parseFromHtml(String html, String pageUrl) async {
    debugPrint('[Parser] 收到 HTML 大小: ${html.length} 字节');
    return _callApi('页面URL: $pageUrl\n\n$html');
  }

  // ── 从 PDF 文件解析 ──────────────────────────────
  // 千问支持在 user content 里传 file 类型（base64），直接理解 PDF 表格结构
  static Future<List<Course>> parseFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    final b64   = base64Encode(bytes);

    final resp = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': _userPrompt},
              {
                'type': 'file',
                'file': {
                  'filename':   file.uri.pathSegments.last,
                  'file_type':  'application/pdf',
                  'file_data':  'data:application/pdf;base64,$b64',
                },
              },
            ],
          },
        ],
        'max_tokens':  4096,
        'extra_body':  {'enable_thinking': false},
      }),
    ).timeout(const Duration(seconds: 120));

    return _parseResponse(resp);
  }

  // ── 调用百炼 API（文本内容）─────────────────────
  static Future<List<Course>> _callApi(String content) async {
    final body = jsonEncode({
      'model': _model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user',   'content': '$_userPrompt$content'},
      ],
      'max_tokens': 4096,
      'extra_body': {'enable_thinking': false},
    });

    debugPrint('[Parser] 开始请求 API，body 大小: ${body.length} 字节');
    final t0 = DateTime.now();

    final resp = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type':  'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: body,
    ).timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        debugPrint('[Parser] ⚠️ 超时！已等待 ${DateTime.now().difference(t0).inSeconds}s');
        throw TimeoutException('API 请求超时，请检查网络连接或 API Key 是否有效');
      },
    );

    debugPrint('[Parser] 收到响应，耗时: ${DateTime.now().difference(t0).inSeconds}s，状态码: ${resp.statusCode}');
    return _parseResponse(resp);
  }

  // ── 解析 API 响应 ────────────────────────────────
  static List<Course> _parseResponse(http.Response resp) {
    if (resp.statusCode != 200) {
      final err = jsonDecode(utf8.decode(resp.bodyBytes));
      final msg = err['error']?['message'] ?? err['message'] ?? resp.body;
      throw Exception('API 错误 ${resp.statusCode}: $msg');
    }

    final data    = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text    = data['choices'][0]['message']['content'] as String;
    final cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'),     '')
        .trim();

    final list = jsonDecode(cleaned) as List;
    return list.map((e) => _map(e as Map<String, dynamic>)).toList();
  }

  // ── 清理 HTML ────────────────────────────────────
  // 目标：从几百KB压缩到几KB，只保留课表相关结构
  static String _cleanHtml(String html) {
    var s = html
        // 去掉 script / style / head
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>',   caseSensitive: false), '')
        .replaceAll(RegExp(r'<head[\s\S]*?</head>',     caseSensitive: false), '')
        // 去掉 HTML 注释
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        // 去掉所有标签属性（保留标签名即可，减少大量无用字符）
        .replaceAll(RegExp(r'<(\w+)[^>]*>'), '<\$1>')
        // 压缩连续空白
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        // 去掉空行
        .replaceAll(RegExp(r'(\n\s*){2,}'), '\n')
        .trim();

    // 超过 40000 字符时截断（约 10K token，够解析课表了）
    if (s.length > 40000) s = s.substring(0, 40000);
    return s;
  }

  static Course _map(Map<String, dynamic> m) => Course(
        name:         m['name']          as String,
        weekday:      m['weekday']        as int,
        startSection: m['startSection']   as int,
        endSection:   m['endSection']     as int,
        location:     (m['location']      as String?) ?? '',
        teacher:      (m['teacher']       as String?) ?? '',
        weeks:        (m['weeks'] as List).cast<int>(),
      );
}