import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/course.dart';
import '../services/semester_storage.dart';
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
  String  _currentUrl  = '';
  bool    _webReady    = false;
  _Status _status      = _Status.idle;
  String? _errorMsg;
  List<Course> _parsed = [];

  // 地址栏
  final _urlController = TextEditingController();
  final _urlFocus      = FocusNode();

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _navigate() {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) url = 'https://$url';
    _webCtrl?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    _urlFocus.unfocus();
  }

  Future<void> _capture() async {
    if (_webCtrl == null) return;
    setState(() { _status = _Status.loading; _errorMsg = null; });

    try {
      debugPrint('[Capture] 开始，先写入 JS 清理脚本...');

      // Step 1：把清理好的内容存到全局变量 __capturedHtml
      const jsStore = r"""
(function() {
  try {
    var doc = document.cloneNode(true);
    ['script','style','link','meta','noscript','iframe','svg','img','canvas']
      .forEach(function(tag) {
        doc.querySelectorAll(tag).forEach(function(el){ el.remove(); });
      });
    var body = doc.body ? doc.body.innerHTML : doc.documentElement.innerHTML;
    body = body.replace(/<!--[\s\S]*?-->/g, '');
    body = body.replace(/<(\w+)[^>]*>/g, '<$1>');
    body = body.replace(/\s{2,}/g, ' ').trim();
    if (body.length > 30000) body = body.substring(0, 30000);
    window.__capturedHtml = body;
    window.__capturedDone = true;
  } catch(e) {
    window.__capturedHtml = 'ERROR:' + e.toString();
    window.__capturedDone = true;
  }
})();
""";

      // fire-and-forget 注入
      // ignore: discarded_futures
      _webCtrl!.evaluateJavascript(source: jsStore);
      debugPrint('[Capture] 脚本已注入，开始轮询结果...');

      // Step 2：轮询读取 __capturedDone，每 300ms 检查一次，最多等 20 秒
      String html = '';
      for (int i = 0; i < 67; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        final done = await _webCtrl!
            .evaluateJavascript(source: 'window.__capturedDone === true')
            .timeout(const Duration(seconds: 3));
        debugPrint('[Capture] 轮询 #$i done=$done');
        if (done == true || done.toString() == 'true') {
          final result = await _webCtrl!
              .evaluateJavascript(source: 'window.__capturedHtml || ""')
              .timeout(const Duration(seconds: 5));
          html = result?.toString() ?? '';
          // 清理全局变量
          // ignore: discarded_futures
          _webCtrl!.evaluateJavascript(
              source: 'delete window.__capturedHtml; delete window.__capturedDone;');
          break;
        }
      }

      debugPrint('[Capture] 获取到内容大小: ${html.length} 字节');

      if (html.isEmpty || html == 'null' || html == 'undefined') {
        throw Exception('未能获取页面内容，请确认页面已完全加载');
      }
      if (html.startsWith('ERROR:')) {
        throw Exception('JS 执行错误: ${html.substring(6)}');
      }

      setState(() => _status = _Status.parsing);
      final courses = await CourseScheduleParser.parseFromHtml(html, _currentUrl);
      if (!mounted) return;
      setState(() { _status = _Status.preview; _parsed = courses; });

    } catch (e) {
      if (!mounted) return;
      debugPrint('[Capture] 失败: $e');
      setState(() { _status = _Status.error; _errorMsg = e.toString(); });
    }
  }

  Future<void> _confirmImport() async {
    // 弹出命名对话框
    final name = await _askSemesterName();
    if (name == null || !mounted) return;
    setState(() => _status = _Status.saving);
    final id = await SemesterStorage.create(name);
    for (final c in _parsed) await SemesterStorage.addCourse(id, c);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<String?> _askSemesterName() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('为本次导入命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如：2024-2025 秋季'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().isEmpty ? '未命名学期' : ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _reset() => setState(() {
    _status = _Status.idle; _errorMsg = null; _parsed = [];
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // WebView 始终保留在树中，避免 channel 断开
    // 状态覆盖层用 Stack 叠加在 WebView 上面
    return Stack(children: [
      // ── 浏览器主体（始终存在）──────────────────────
      Column(children: [
        _AddressBar(
          controller: _urlController,
          focusNode:  _urlFocus,
          isLoading:  false,
          onSubmit:   _navigate,
          onBack:     () => _webCtrl?.goBack(),
          onForward:  () => _webCtrl?.goForward(),
          onReload:   () => _webCtrl?.reload(),
        ),
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri('about:blank')),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/120.0.0.0 Safari/537.36',
            ),
            onWebViewCreated: (c) {
              _webCtrl = c;
              setState(() => _webReady = true);
            },
            onLoadStart: (_, url) {
              final u = url?.toString() ?? '';
              if (u.isNotEmpty && u != 'about:blank') {
                setState(() => _urlController.text = u);
              }
            },
            onLoadStop: (_, url) {
              final u = url?.toString() ?? '';
              if (u.isNotEmpty && u != 'about:blank') {
                setState(() {
                  _currentUrl = u;
                  _urlController.text = u;
                });
              }
            },
            onLoadError: (_, __, ___, ____) => setState(() {}),
          ),
        ),
      ]),

      // 底部抓取按钮（idle 时显示）
      if (_status == _Status.idle)
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _CaptureBar(
            canCapture: _webReady,
            onCapture:  _capture,
          ),
        ),

      // 状态覆盖层（非 idle 时叠在 WebView 上）
      if (_status != _Status.idle)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _StatusOverlay(
              status:    _status,
              errorMsg:  _errorMsg,
              courses:   _parsed,
              onRetry:   _reset,
              onConfirm: _confirmImport,
            ),
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
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('为本次导入命名'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '如：2024-2025 秋季'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context,
                ctrl.text.trim().isEmpty ? '未命名学期' : ctrl.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() => _status = _Status.saving);
    final id = await SemesterStorage.create(name);
    for (final c in _parsed) await SemesterStorage.addCourse(id, c);
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

// ── 浏览器地址栏 ─────────────────────────────────────
class _AddressBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onReload;

  const _AddressBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
    required this.onForward,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            // 后退
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              onPressed: onBack,
              visualDensity: VisualDensity.compact,
            ),
            // 前进
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              onPressed: onForward,
              visualDensity: VisualDensity.compact,
            ),
            // 地址输入框
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(fontSize: 13),
                  textInputAction: TextInputAction.go,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: '输入教务系统网址',
                    hintStyle: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        size: 14, color: Colors.grey.shade400),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 30, minHeight: 0),
                  ),
                  onSubmitted: (_) => onSubmit(),
                  onTap: () => controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  ),
                ),
              ),
            ),
            // 刷新 / 停止
            IconButton(
              icon: Icon(
                isLoading
                    ? Icons.close_rounded
                    : Icons.refresh_rounded,
                size: 20,
              ),
              onPressed: onReload,
              visualDensity: VisualDensity.compact,
            ),
          ]),
          // 加载进度条
          if (isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}

// ── 底部抓取按钮 ─────────────────────────────────────
class _CaptureBar extends StatelessWidget {
  final bool canCapture;
  final VoidCallback onCapture;

  const _CaptureBar({required this.canCapture, required this.onCapture});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canCapture ? onCapture : null,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: Text(canCapture ? '抓取当前页面课表' : '请先导航到课表页面'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
        ),
      );
}