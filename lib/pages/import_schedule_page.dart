import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/course.dart';
import '../services/course_storage.dart';
import '../services/course_schedule_parser.dart';

class ImportSchedulePage extends StatefulWidget {
  const ImportSchedulePage({super.key});

  @override
  State<ImportSchedulePage> createState() => _ImportSchedulePageState();
}

class _ImportSchedulePageState extends State<ImportSchedulePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入课表'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.language_rounded),       text: '网页抓取'),
            Tab(icon: Icon(Icons.picture_as_pdf_rounded), text: 'PDF 导入'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _WebImportTab(),
          _PdfImportTab(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// Tab 1：网页抓取
// ════════════════════════════════════════════════════════
class _WebImportTab extends StatefulWidget {
  const _WebImportTab();
  @override
  State<_WebImportTab> createState() => _WebImportTabState();
}

class _WebImportTabState extends State<_WebImportTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  InAppWebViewController? _webCtrl;
  String  _currentUrl = '';
  bool    _canCapture = false;
  _Status _status     = _Status.idle;
  String? _errorMsg;
  List<Course> _parsed = [];

  Future<void> _capture() async {
    if (_webCtrl == null) return;
    setState(() { _status = _Status.loading; _errorMsg = null; });

    try {
      final html = await _webCtrl!
          .evaluateJavascript(source: "document.documentElement.outerHTML")
          .timeout(const Duration(seconds: 10));
      if (html == null || html.toString().trim().isEmpty) {
        throw Exception('页面内容为空，请等待页面加载完成后重试');
      }
      setState(() => _status = _Status.parsing);
      final courses = await CourseScheduleParser.parseFromHtml(
          html.toString(), _currentUrl);
      if (!mounted) return;
      setState(() { _status = _Status.preview; _parsed = courses; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _status = _Status.error; _errorMsg = e.toString(); });
    }
  }

  Future<void> _confirmImport() async {
    setState(() => _status = _Status.saving);
    for (final c in _parsed) await CourseStorage.addCourse(c);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _reset() => setState(() {
    _status = _Status.idle; _errorMsg = null; _parsed = [];
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_status != _Status.idle) {
      return _StatusOverlay(
        status: _status, errorMsg: _errorMsg,
        courses: _parsed, onRetry: _reset, onConfirm: _confirmImport,
      );
    }

    return Stack(children: [
      Column(children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.07),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '在下方浏览器中登录教务系统，导航到课表页面后点击「抓取」',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                  'Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (c) => _webCtrl = c,
            onLoadStop: (_, url) => setState(() {
              _currentUrl = url?.toString() ?? '';
              _canCapture = _currentUrl.isNotEmpty &&
                  _currentUrl != 'about:blank';
            }),
          ),
        ),
      ]),
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: _CaptureBar(
          canCapture: _canCapture,
          url: _currentUrl,
          onCapture: _capture,
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════
// Tab 2：PDF 导入
// ════════════════════════════════════════════════════════
class _PdfImportTab extends StatefulWidget {
  const _PdfImportTab();
  @override
  State<_PdfImportTab> createState() => _PdfImportTabState();
}

class _PdfImportTabState extends State<_PdfImportTab> {
  _Status _status  = _Status.idle;
  String? _errorMsg;
  String? _fileName;
  List<Course> _parsed = [];

  Future<void> _pickAndParse() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _status = _Status.parsing;
      _fileName = result.files.single.name;
      _errorMsg = null;
    });

    try {
      final courses = await CourseScheduleParser.parseFromPdf(
          File(result.files.single.path!));
      if (!mounted) return;
      setState(() { _status = _Status.preview; _parsed = courses; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _status = _Status.error; _errorMsg = e.toString(); });
    }
  }

  Future<void> _confirmImport() async {
    setState(() => _status = _Status.saving);
    for (final c in _parsed) await CourseStorage.addCourse(c);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _reset() => setState(() {
    _status = _Status.idle; _errorMsg = null; _parsed = [];
  });

  @override
  Widget build(BuildContext context) {
    if (_status != _Status.idle) {
      return _StatusOverlay(
        status: _status, errorMsg: _errorMsg, fileName: _fileName,
        courses: _parsed, onRetry: _reset, onConfirm: _confirmImport,
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
                color: primary.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.picture_as_pdf_rounded, size: 44, color: primary),
          ),
          const SizedBox(height: 22),
          const Text('导入 PDF 课表',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            '选择从教务系统导出的课表 PDF，\nAI 将自动识别所有课程信息。',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickAndParse,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('选择 PDF 文件'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 共用状态层
// ════════════════════════════════════════════════════════
enum _Status { idle, loading, parsing, saving, preview, error }

class _StatusOverlay extends StatelessWidget {
  final _Status status;
  final String? errorMsg;
  final String? fileName;
  final List<Course> courses;
  final VoidCallback onRetry;
  final VoidCallback onConfirm;

  const _StatusOverlay({
    required this.status, required this.courses,
    required this.onRetry, required this.onConfirm,
    this.errorMsg, this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: switch (status) {
        _Status.loading  => _Spinner(key: const ValueKey('l'), label: '读取中…'),
        _Status.parsing  => _Spinner(key: const ValueKey('p'),
            label: 'AI 正在识别课程\n通常需要 10–20 秒…'),
        _Status.saving   => _Spinner(key: const ValueKey('s'), label: '写入课表中…'),
        _Status.error    => _ErrorCard(
            key: const ValueKey('e'),
            message: errorMsg ?? '未知错误', onRetry: onRetry),
        _Status.preview  => _PreviewList(
            key: const ValueKey('v'),
            courses: courses, fileName: fileName,
            onConfirm: onConfirm, onReselect: onRetry),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  final String label;
  const _Spinner({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary, strokeWidth: 3),
          const SizedBox(height: 22),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, height: 1.5)),
        ]),
      );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded,
                size: 52, color: Colors.red.shade400),
            const SizedBox(height: 14),
            const Text('解析失败',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      height: 1.4)),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重新选择'),
            ),
          ]),
        ),
      );
}

class _PreviewList extends StatelessWidget {
  final List<Course> courses;
  final String? fileName;
  final VoidCallback onConfirm;
  final VoidCallback onReselect;
  const _PreviewList({
    super.key, required this.courses, required this.onConfirm,
    required this.onReselect, this.fileName,
  });

  static const _wd = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  String _weeksStr(List<int> w) {
    if (w.isEmpty) return '—';
    final s = [...w]..sort();
    final segs = <String>[];
    int a = s[0], b = s[0];
    for (int i = 1; i < s.length; i++) {
      if (s[i] == b + 1) { b = s[i]; }
      else { segs.add(a == b ? '$a' : '$a–$b'); a = b = s[i]; }
    }
    segs.add(a == b ? '$a' : '$a–$b');
    return '${segs.join('、')} 周';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('识别到 ${courses.length} 门课程',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
              if (fileName != null)
                Text(fileName!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          )),
          TextButton(
            onPressed: onReselect,
            child: Text('重选',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          itemCount: courses.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = courses[i];
            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Wrap(spacing: 10, runSpacing: 3, children: [
                  _tag(Icons.calendar_today_rounded,
                      '${_wd[c.weekday.clamp(1, 7)]} 第${c.startSection}–${c.endSection}节'),
                  if (c.location.isNotEmpty)
                    _tag(Icons.location_on_rounded, c.location),
                  if (c.teacher.isNotEmpty)
                    _tag(Icons.person_rounded, c.teacher),
                  _tag(Icons.repeat_rounded, _weeksStr(c.weeks)),
                ]),
              ]),
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: Text('导入 ${courses.length} 门课程'),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _tag(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]);
}

// ── WebView 底部抓取栏 ───────────────────────────────
class _CaptureBar extends StatelessWidget {
  final bool canCapture;
  final String url;
  final VoidCallback onCapture;
  const _CaptureBar(
      {required this.canCapture, required this.url, required this.onCapture});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (url.isNotEmpty && url != 'about:blank')
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(url,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade400),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canCapture ? onCapture : null,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('抓取当前页面课表'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
              ),
            ),
          ]),
        ),
      );
}