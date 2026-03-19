import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_storage.dart';

class AddCoursePage extends StatefulWidget {
  const AddCoursePage({super.key});

  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {
  final _formKey = GlobalKey<FormState>();

  // ── 表单字段控制器 ────────────────────────
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();

  int _weekday = 1;        // 1=周一 … 7=周日
  int _startSection = 1;
  int _endSection = 2;

  // 周次：用 Set 记录勾选的周
  final Set<int> _selectedWeeks = {};
  static const int _totalWeeks = 20;

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _teacherCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════
  // 保存
  // ════════════════════════════════════════
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWeeks.isEmpty) {
      _showSnack('请至少选择一个周次');
      return;
    }
    if (_endSection < _startSection) {
      _showSnack('结束节次不能早于开始节次');
      return;
    }

    setState(() => _saving = true);
    final course = Course(
      name: _nameCtrl.text.trim(),
      weekday: _weekday,
      startSection: _startSection,
      endSection: _endSection,
      location: _locationCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      weeks: _selectedWeeks.toList()..sort(),
    );
    await CourseStorage.addCourse(course);
    if (mounted) Navigator.pop(context);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加课程'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('保存',
                    style: TextStyle(
                        color: primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── 基本信息 ──────────────────────────
            _SectionLabel('基本信息'),
            _Field(
              controller: _nameCtrl,
              label: '课程名称',
              icon: Icons.book_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入课程名称' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _teacherCtrl,
              label: '教师',
              icon: Icons.person_outline_rounded,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入教师姓名' : null,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: _locationCtrl,
              label: '上课地点',
              icon: Icons.location_on_outlined,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入上课地点' : null,
            ),

            const SizedBox(height: 24),

            // ── 时间 ──────────────────────────────
            _SectionLabel('上课时间'),
            _Card(
              child: Column(
                children: [
                  // 星期
                  _LabelRow(
                    label: '星期',
                    child: _WeekdayPicker(
                      value: _weekday,
                      onChanged: (v) => setState(() => _weekday = v),
                    ),
                  ),
                  const Divider(height: 1),
                  // 开始节次
                  _LabelRow(
                    label: '开始节次',
                    child: _SectionPicker(
                      value: _startSection,
                      min: 1,
                      max: 15,
                      onChanged: (v) => setState(() {
                        _startSection = v;
                        if (_endSection < v) _endSection = v;
                      }),
                    ),
                  ),
                  const Divider(height: 1),
                  // 结束节次
                  _LabelRow(
                    label: '结束节次',
                    child: _SectionPicker(
                      value: _endSection,
                      min: _startSection,
                      max: 15,
                      onChanged: (v) => setState(() => _endSection = v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── 周次 ──────────────────────────────
            _SectionLabel('上课周次'),
            Row(
              children: [
                _ChipAction(
                  label: '全选',
                  onTap: () => setState(() => _selectedWeeks
                      .addAll(List.generate(_totalWeeks, (i) => i + 1))),
                ),
                const SizedBox(width: 8),
                _ChipAction(
                  label: '单周',
                  onTap: () => setState(() {
                    _selectedWeeks.clear();
                    for (int i = 1; i <= _totalWeeks; i += 2) {
                      _selectedWeeks.add(i);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                _ChipAction(
                  label: '双周',
                  onTap: () => setState(() {
                    _selectedWeeks.clear();
                    for (int i = 2; i <= _totalWeeks; i += 2) {
                      _selectedWeeks.add(i);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                _ChipAction(
                  label: '清空',
                  onTap: () =>
                      setState(() => _selectedWeeks.clear()),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_totalWeeks, (i) {
                    final week = i + 1;
                    final selected = _selectedWeeks.contains(week);
                    return GestureDetector(
                      onTap: () => setState(() => selected
                          ? _selectedWeeks.remove(week)
                          : _selectedWeeks.add(week)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? primary
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$week',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 子组件
// ════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelRow({required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          child,
        ],
      ),
    );
  }
}

// 星期选择器
class _WeekdayPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _WeekdayPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const days = ['一', '二', '三', '四', '五', '六', '日'];
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final selected = value == i + 1;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.only(left: 4),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selected ? primary : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              days[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// 节次选择器（+/- 步进）
class _SectionPicker extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _SectionPicker({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Btn(
          icon: Icons.remove,
          active: value > min,
          color: primary,
          onTap: () { if (value > min) onChanged(value - 1); },
        ),
        SizedBox(
          width: 32,
          child: Text(
            '第$value节',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        _Btn(
          icon: Icons.add,
          active: value < max,
          color: primary,
          onTap: () { if (value < max) onChanged(value + 1); },
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _Btn(
      {required this.icon,
      required this.active,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.10) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 14,
            color: active ? color : Colors.grey.shade300),
      ),
    );
  }
}

// 快捷选周按钮
class _ChipAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ChipAction({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}