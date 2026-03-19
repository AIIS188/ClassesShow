import 'package:flutter/material.dart';
import '../models/semester.dart';
import '../services/semester_storage.dart';
import 'main_page.dart' show semesterVersion;

class SemesterManagePage extends StatefulWidget {
  const SemesterManagePage({super.key});

  @override
  State<SemesterManagePage> createState() => _SemesterManagePageState();
}

class _SemesterManagePageState extends State<SemesterManagePage> {
  List<Semester> _semesters = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _semesters = SemesterStorage.getAll());

  // ── 新建学期 ─────────────────────────────────────────
  Future<void> _create() async {
    final name = await _showNameDialog(title: '新建学期', hint: '如：2024-2025 春季');
    if (name == null || name.trim().isEmpty) return;
    await SemesterStorage.create(name.trim());
    _reload();
  }

  // ── 激活学期 ─────────────────────────────────────────
  Future<void> _activate(Semester s) async {
    if (s.isActive) return;
    await SemesterStorage.setActive(s.id);
    semesterVersion.value++;   // 通知所有监听页面刷新
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到「${s.name}」'), duration: const Duration(seconds: 1)),
      );
    }
  }

  // ── 重命名 ───────────────────────────────────────────
  Future<void> _rename(Semester s) async {
    final name = await _showNameDialog(title: '重命名', hint: s.name, initial: s.name);
    if (name == null || name.trim().isEmpty) return;
    await SemesterStorage.rename(s.id, name.trim());
    _reload();
  }

  // ── 删除 ─────────────────────────────────────────────
  Future<void> _delete(Semester s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除学期'),
        content: Text('确定删除「${s.name}」？\n该学期所有课程将一并删除，无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('删除',
                  style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (confirm != true) return;
    await SemesterStorage.delete(s.id);
    _reload();
  }

  Future<String?> _showNameDialog({
    required String title,
    required String hint,
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('确定')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学期管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '新建学期',
            onPressed: _create,
          ),
        ],
      ),
      body: _semesters.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('暂无学期', style: TextStyle(color: Colors.grey.shade400)),
              ]),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _semesters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = _semesters[i];
                return _SemesterTile(
                  semester:   s,
                  onActivate: () => _activate(s),
                  onRename:   () => _rename(s),
                  onDelete:   _semesters.length > 1 ? () => _delete(s) : null,
                );
              },
            ),
    );
  }
}

class _SemesterTile extends StatelessWidget {
  final Semester semester;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  const _SemesterTile({
    required this.semester,
    required this.onActivate,
    required this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final active   = semester.isActive;

    return Container(
      decoration: BoxDecoration(
        color: active ? primary.withOpacity(0.07) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? primary.withOpacity(0.3) : Colors.grey.shade200,
          width: active ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: onActivate,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? primary : Colors.transparent,
              border: Border.all(
                color: active ? primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: active
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          semester.name,
          style: TextStyle(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? primary : null,
          ),
        ),
        subtitle: Text(
          active ? '当前学期' : '点击圆圈切换',
          style: TextStyle(
            fontSize: 12,
            color: active ? primary.withOpacity(0.7) : Colors.grey.shade400,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
              onPressed: onRename,
              tooltip: '重命名',
            ),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade300),
                onPressed: onDelete,
                tooltip: '删除',
              )
            else
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
}
