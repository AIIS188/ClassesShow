import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/course.dart';

/// 课表解析服务 - 使用阿里云百炼 / Coding Plan API
///
/// 百炼兼容 OpenAI 格式，endpoint 和 key 根据套餐类型不同：
///   普通按量付费：baseUrl = https://dashscope.aliyuncs.com/compatible-mode/v1
///                 apiKey  = sk-xxxxx
///   Coding Plan： baseUrl = https://coding.dashscope.aliyuncs.com/v1
///                 apiKey  = sk-sp-xxxxx
class CourseScheduleParser {
  // ⚠️ 填入你的配置
  static const _apiKey  = 'YOUR_BAILIAN_API_KEY';   // sk-xxxxx 或 sk-sp-xxxxx
  static const _baseUrl = 'https://coding.dashscope.aliyuncs.com/v1'; // Coding Plan
  // static const _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1'; // 按量付费

  // 课表解析推荐用 qwen-plus，理解表格结构好，性价比高
  // 若用 Coding Plan 套餐，模型名称照用即可
  static const _model = 'qwen-plus';

  static const _systemPrompt = '你是一个专业的课程表解析助手，擅长从各种格式的课表中提取结构化信息。';

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
  static Future<List<Course>> parseFromHtml(String html, String pageUrl) async {
    final cleaned = _cleanHtml(html);
    return _callApi('页面URL: $pageUrl\n\n$cleaned');
  }

  // ── 从 PDF 文件解析（提取文本后发送）──────────────
  static Future<List<Course>> parseFromPdf(File file) async {
    final text = await _extractPdfText(file);
    if (text.trim().isEmpty) {
      throw Exception('无法提取 PDF 文字内容，请确认不是扫描版图片 PDF。');
    }
    return _callApi(text);
  }

  // ── 调用百炼 API（OpenAI 兼容格式）──────────────
  static Future<List<Course>> _callApi(String content) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user',   'content': '$_userPrompt$content'},
        ],
        'max_tokens': 4096,
        // 关闭思考模式（qwen3 系列默认开启，会增加 token 消耗）
        'extra_body': {'enable_thinking': false},
      }),
    ).timeout(const Duration(seconds: 60));

    if (resp.statusCode != 200) {
      final err = jsonDecode(utf8.decode(resp.bodyBytes));
      final msg = err['error']?['message'] ?? err['message'] ?? resp.body;
      throw Exception('API 错误 ${resp.statusCode}: $msg');
    }

    final data    = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final text    = data['choices'][0]['message']['content'] as String;
    final cleaned = text
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '') // 去掉思考链
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final list = jsonDecode(cleaned) as List;
    return list.map((e) => _map(e as Map<String, dynamic>)).toList();
  }

  // ── PDF 文本提取 ─────────────────────────────────
  static Future<String> _extractPdfText(File file) async {
    final bytes    = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text     = PdfTextExtractor(document).extractText();
    document.dispose();
    return text;
  }

  // ── 清理 HTML ────────────────────────────────────
  static String _cleanHtml(String html) {
    var s = html
        .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[\s\S]*?</style>',  caseSensitive: false), '')
        .replaceAll(RegExp(r'<head[\s\S]*?</head>',    caseSensitive: false), '');
    if (s.length > 80000) s = s.substring(0, 80000);
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