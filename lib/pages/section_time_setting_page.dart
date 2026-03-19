import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/section_time.dart';
import '../services/section_time_storage.dart';

// ════════════════════════════════════════════════════════
// 分组定义
// ════════════════════════════════════════════════════════
class _Group {
  final String label;
  final String icon;
  final Color color;
  const _Group({required this.label, required this.icon, required this.color});
}

const _kGroups = [
  _Group(label: '上午', icon: '☀️', color: Color(0xFFFFF3CD)),
  _Group(label: '下午', icon: '🌤', color: Color(0xFFD4EDFF)),
  _Group(label: '晚上', icon: '🌙', color: Color(0xFFE8E0FF)),
];

// ════════════════════════════════════════════════════════
// 页面
// ════════════════════════════════════════════════════════
class SectionTimeSettingPage extends StatefulWidget {
  const SectionTimeSettingPage({super.key});

  @override
  State<SectionTimeSettingPage> createState() =>
      _SectionTimeSettingPageState();
}

class _SectionTimeSettingPageState extends State<SectionTimeSettingPage> {
  /// 全量节次列表，始终是可变列表
  List<SectionTime> _times = [];
  bool _loading = true;

  /// 快速生成参数
  int _classDuration = 45;
  int _breakDuration = 5;

  /// 每个分组的节数 [上午, 下午, 晚上]
  final List<int> _groupCounts = [4, 6, 1];

  // ── 生命周期 ────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final times     = await SectionTimeStorage.loadTimes();
    final classDur  = await SectionTimeStorage.loadClassDuration();
    final breakDur  = await SectionTimeStorage.loadBreakDuration();
    setState(() {
      _times         = List<SectionTime>.from(times);
      _classDuration = classDur;
      _breakDuration = breakDur;
      _inferGroupCounts();
      _loading = false;
    });
  }

  /// 从已有节次总数推断各分组节数
  void _inferGroupCounts() {
    final total = _times.length;
    // 保持上午/下午尽量用默认值，晚上吸收剩余
    _groupCounts[0] = _groupCounts[0].clamp(0, total);
    _groupCounts[1] = _groupCounts[1].clamp(0, total - _groupCounts[0]);
    _groupCounts[2] = total - _groupCounts[0] - _groupCounts[1];
  }

  int get _totalCount => _groupCounts.fold(0, (a, b) => a + b);

  // ── 保存 ───────────────────────────────────────────
  Future<void> _save() async {
    await SectionTimeStorage.saveAll(
      times:         _times,
      classDuration: _classDuration,
      breakDuration: _breakDuration,
    );
    if (mounted) Navigator.pop(context, List<SectionTime>.from(_times));
  }

  // ── 快速生成 ────────────────────────────────────────
  void _autoGenerate() {
    if (_times.isEmpty) return;
    setState(() {
      final result = <SectionTime>[_times.first];
      for (int i = 1; i < _times.length; i++) {
        result.add(SectionTime.fromPrev(
          section: i + 1,
          prev: result[i - 1],
          classDuration: _classDuration,
          breakDuration: _breakDuration,
        ));
      }
      _times = result;
    });
  }

  // ── 调整分组节数 ────────────────────────────────────
  void _adjustGroupCount(int groupIdx, int delta) {
    final newCount = (_groupCounts[groupIdx] + delta).clamp(0, 15);
    if (newCount == _groupCounts[groupIdx]) return;

    setState(() {
      _groupCounts[groupIdx] = newCount;
      final total = _totalCount;

      if (total > _times.length) {
        // 计算该分组当前最后一节在 _times 中的位置（插入点之前一节）
        // groupEnd（exclusive）= 前面所有分组节数之和 + 本组旧节数
        final oldCount  = newCount - delta; // 修改前的节数
        final groupEnd  = _groupCounts.take(groupIdx).fold(0, (a, b) => a + b)
                          + oldCount; // 本组插入点（在全局中的位置）
        final prevIndex = groupEnd - 1; // 本组最后一节的全局下标

        final toAdd = total - _times.length;
        // 在 groupEnd 位置插入新节次，不影响后续分组
        for (int i = 0; i < toAdd; i++) {
          final insertAt = groupEnd + i;
          final prev     = _times[prevIndex + i]; // 紧前一节
          final newTime  = SectionTime.fromPrev(
            section:       insertAt + 1, // 临时编号，后面统一重编
            prev:          prev,
            classDuration: _classDuration,
            breakDuration: _breakDuration,
          );
          _times.insert(insertAt, newTime);
        }
      } else if (total < _times.length) {
        // 裁减：从本组末尾移除多余节次
        final groupEnd = _groupCounts.take(groupIdx + 1).fold(0, (a, b) => a + b);
        final toRemove = _times.length - total;
        _times.removeRange(groupEnd, groupEnd + toRemove);
      }

      // 统一重编 section 编号（1-based）
      for (int i = 0; i < _times.length; i++) {
        final t = _times[i];
        _times[i] = SectionTime(
          section:     i + 1,
          startHour:   t.startHour,
          startMinute: t.startMinute,
          endHour:     t.endHour,
          endMinute:   t.endMinute,
        );
      }
    });
  }

  // ── 级联更新 ────────────────────────────────────────
  //
  // 打开弹窗前快照各节原时长 & 相邻节原休息间隔，
  // 用户选定新开始时间后：
  //   本节结束 = 新开始 + 原时长
  //   后续每节：开始 = 前节结束 + 原休息间隔，结束 = 新开始 + 原时长
  //
  late List<int> _snapDurations; // 各节时长（分钟）
  late List<int> _snapBreaks;    // 相邻节休息间隔（分钟），索引 i = 第i节与第i+1节之间

  void _snapshot() {
    _snapDurations = _times.map((t) => t.durationMinutes).toList();
    _snapBreaks = List.generate(_times.length, (i) {
      if (i + 1 >= _times.length) return _breakDuration;
      return _times[i + 1].startHour * 60 +
          _times[i + 1].startMinute -
          _times[i].endHour * 60 -
          _times[i].endMinute;
    });
  }

  /// [index] 被修改节在 _times 中的全局下标
  /// [groupEnd] 该分组最后一节的全局下标（exclusive），级联到此为止
  void _cascadeFrom(int index, Duration newStart, int groupEnd) {
    setState(() {
      // 更新本节：保持原时长
      final startMin = newStart.inMinutes;
      final endMin   = startMin + _snapDurations[index];
      _times[index] = SectionTime(
        section:     _times[index].section,
        startHour:   startMin ~/ 60,
        startMinute: startMin % 60,
        endHour:     endMin ~/ 60,
        endMinute:   endMin % 60,
      );

      // 只在同一分组内级联，到 groupEnd 停止
      for (int i = index + 1; i < groupEnd; i++) {
        final prev = _times[i - 1];
        final s = prev.endHour * 60 + prev.endMinute + _snapBreaks[i - 1];
        final e = s + _snapDurations[i];
        _times[i] = SectionTime(
          section:     _times[i].section,
          startHour:   s ~/ 60,
          startMinute: s % 60,
          endHour:     e ~/ 60,
          endMinute:   e % 60,
        );
      }
    });
  }

  Future<void> _openEditor(int index, int groupEnd) async {
    _snapshot();
    final t = _times[index];
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => _TimeWheelSheet(
        section:      t.section,
        initialStart: Duration(hours: t.startHour, minutes: t.startMinute),
        onConfirm:    (newStart) => _cascadeFrom(index, newStart, groupEnd),
      ),
    );
  }

  // ── 按分组切片 ──────────────────────────────────────
  List<List<SectionTime>> get _grouped {
    final result = <List<SectionTime>>[];
    int cursor = 0;
    for (final count in _groupCounts) {
      final end = (cursor + count).clamp(0, _times.length);
      result.add(_times.sublist(cursor, end));
      cursor = end;
    }
    return result;
  }

  // ════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final grouped = _grouped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('节次时间设置'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text('保存并使用',
                style: TextStyle(
                    color: primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                // 快速生成卡片
                _QuickGenCard(
                  classDuration: _classDuration,
                  breakDuration: _breakDuration,
                  onClassChanged: (v) => setState(() => _classDuration = v),
                  onBreakChanged: (v) => setState(() => _breakDuration = v),
                  onGenerate: _autoGenerate,
                ),
                const SizedBox(height: 24),

                // 三个分组
                for (int g = 0; g < _kGroups.length; g++) ...[
                  _GroupHeader(
                    group: _kGroups[g],
                    count: _groupCounts[g],
                    onDecrement: () => _adjustGroupCount(g, -1),
                    onIncrement: () => _adjustGroupCount(g, 1),
                  ),
                  const SizedBox(height: 8),
                  if (grouped[g].isNotEmpty)
                    _SectionCard(
                      group: _kGroups[g],
                      times: grouped[g],
                      onEdit: (t) {
                        final idx =
                            _times.indexWhere((x) => x.section == t.section);
                        // groupEnd = 该分组前几组的节数之和
                        final groupEnd = _groupCounts
                            .take(g + 1)
                            .fold(0, (a, b) => a + b);
                        if (idx >= 0) _openEditor(idx, groupEnd);
                      },
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('（已关闭）',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 分组标题行（含 +/− 节数编辑）
// ════════════════════════════════════════════════════════
class _GroupHeader extends StatelessWidget {
  final _Group group;
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _GroupHeader({
    required this.group,
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: group.color,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(group.icon, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 10),
        Text('${group.label}课程节数',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        const Spacer(),
        _CircleBtn(
          icon: Icons.remove,
          color: primary,
          active: count > 0,
          onTap: onDecrement,
        ),
        SizedBox(
          width: 34,
          child: Text('$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        _CircleBtn(
          icon: Icons.add,
          color: primary,
          active: count < 15,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
// 节次列表卡片
// ════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final _Group group;
  final List<SectionTime> times;
  final ValueChanged<SectionTime> onEdit;

  const _SectionCard({
    required this.group,
    required this.times,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: times.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          return Column(
            children: [
              InkWell(
                onTap: () => onEdit(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: group.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text('${t.section}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Text('第 ${t.section} 节课',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        '${t.startLabel}  –  ${t.endLabel}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              if (i < times.length - 1)
                Divider(
                    height: 1, indent: 16, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 滚轮时间选择弹窗（只选开始时间）
// ════════════════════════════════════════════════════════
class _TimeWheelSheet extends StatefulWidget {
  final int section;
  final Duration initialStart;
  final ValueChanged<Duration> onConfirm;

  const _TimeWheelSheet({
    required this.section,
    required this.initialStart,
    required this.onConfirm,
  });

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hour;
  late int _minute;

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialStart.inHours.clamp(0, 23);
    _minute = widget.initialStart.inMinutes % 60;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  String get _timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: 310,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 操作栏
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            child: Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消',
                      style: TextStyle(
                          color: CupertinoColors.destructiveRed)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('第 ${widget.section} 节  开始时间',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_timeLabel,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: primary)),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: () {
                    widget.onConfirm(
                        Duration(hours: _hour, minutes: _minute));
                    Navigator.pop(context);
                  },
                  child: Text('完成',
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Text(
            '结束时间和后续节次将自动跟随调整',
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 4),

          // 滚轮
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 选中高亮
                IgnorePointer(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 小时
                    SizedBox(
                      width: 90,
                      child: CupertinoPicker(
                        scrollController: _hourCtrl,
                        itemExtent: 44,
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                                background: Colors.transparent),
                        onSelectedItemChanged: (h) =>
                            setState(() => _hour = h),
                        children: List.generate(
                          24,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(':',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w200)),
                    // 分钟
                    SizedBox(
                      width: 90,
                      child: CupertinoPicker(
                        scrollController: _minCtrl,
                        itemExtent: 44,
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                                background: Colors.transparent),
                        onSelectedItemChanged: (m) =>
                            setState(() => _minute = m),
                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// 快速生成卡片
// ════════════════════════════════════════════════════════
class _QuickGenCard extends StatelessWidget {
  final int classDuration;
  final int breakDuration;
  final ValueChanged<int> onClassChanged;
  final ValueChanged<int> onBreakChanged;
  final VoidCallback onGenerate;

  const _QuickGenCard({
    required this.classDuration,
    required this.breakDuration,
    required this.onClassChanged,
    required this.onBreakChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
              Text('快速生成',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const Spacer(),
              GestureDetector(
                onTap: onGenerate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('生成',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DurationRow(
              label: '每节课上课时长',
              value: classDuration,
              min: 20,
              max: 120,
              onChanged: onClassChanged),
          const SizedBox(height: 10),
          _DurationRow(
              label: '课间休息时长',
              value: breakDuration,
              min: 0,
              max: 60,
              onChanged: onBreakChanged),
          const SizedBox(height: 8),
          Text(
            '* 点击「生成」从第1节按设定时长自动推算全部节次',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _DurationRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500))),
        _CircleBtn(
          icon: Icons.remove,
          color: primary,
          active: value > min,
          onTap: () { if (value > min) onChanged(value - 5); },
        ),
        SizedBox(
          width: 58,
          child: Text('$value min',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        _CircleBtn(
          icon: Icons.add,
          color: primary,
          active: value < max,
          onTap: () { if (value < max) onChanged(value + 5); },
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════
// 通用圆形按钮
// ════════════════════════════════════════════════════════
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color.withOpacity(0.12) : Colors.grey.shade100,
          border: Border.all(
            color: active ? color.withOpacity(0.35) : Colors.grey.shade300,
          ),
        ),
        child: Icon(icon,
            size: 14,
            color: active ? color : Colors.grey.shade400),
      ),
    );
  }
}