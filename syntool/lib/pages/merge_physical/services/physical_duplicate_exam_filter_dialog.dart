import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

import '../models/physical_duplicate_exam_models.dart';
import 'physical_duplicate_exam_service.dart';

class PhysicalDuplicateExamFilterDialog extends StatefulWidget {
  final String token;
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final String initialKeyword;
  final PhysicalDuplicateExamService service;

  const PhysicalDuplicateExamFilterDialog({
    super.key,
    required this.token,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialKeyword,
    required this.service,
  });

  @override
  State<PhysicalDuplicateExamFilterDialog> createState() =>
      _PhysicalDuplicateExamFilterDialogState();
}

class _PhysicalDuplicateExamFilterDialogState
    extends State<PhysicalDuplicateExamFilterDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _keywordController;
  bool _isLoading = false;
  String? _loadingMessage;
  bool _hasSearched = false;
  List<DuplicateExamGroup> _groups = const [];
  OverlayEntry? _messageOverlay;
  Timer? _messageTimer;
  CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _keywordController = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _cancelToken.cancel();
    _hideMessageOverlay();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_startDate.isAfter(_endDate)) {
      _showMessage('开始日期不能大于结束日期');
      return;
    }

    // 每次搜索前重置取消令牌
    _cancelToken = CancelToken();

    setState(() {
      _isLoading = true;
      _loadingMessage = '正在查询重复体检档案...';
    });

    try {
      final groups = await widget.service.searchDuplicateExams(
        token: widget.token,
        params: DuplicateExamSearchParams(
          startDate: _startDate,
          endDate: _endDate,
          keyword: _keywordController.text,
        ),
        cancelToken: _cancelToken,
        onProgress: (currentPage, totalPages) {
          if (mounted) {
            setState(() {
              _loadingMessage = '正在查询重复体检档案（第 $currentPage/$totalPages 页）...';
            });
          }
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _hasSearched = true;
        _groups = groups;
      });
    } catch (e) {
      final msg = e.toString();
      // 用户主动取消时不显示错误提示
      if (!msg.contains('已取消')) {
        _showMessage(msg.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentMaterialBanner();
    messenger.hideCurrentSnackBar();

    _messageTimer?.cancel();
    _messageOverlay?.remove();

    final style = _resolveMessageStyle(message);
    _messageOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 22,
        left: 0,
        right: 0,
        child: IgnorePointer(
          ignoring: false,
          child: SafeArea(
            bottom: false,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: style.borderColor, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: style.shadowColor,
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: style.iconBackgroundColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(style.icon, color: style.iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: style.textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _hideMessageOverlay,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              color: style.textColor.withOpacity(0.75),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_messageOverlay!);
    _messageTimer = Timer(const Duration(seconds: 4), _hideMessageOverlay);
  }

  _MessageStyle _resolveMessageStyle(String message) {
    if (message.contains('成功')) {
      return const _MessageStyle(
        icon: Icons.check_circle_rounded,
        backgroundColor: Color(0xFFE8F7EE),
        borderColor: Color(0xFF8FD0A6),
        iconBackgroundColor: Color(0xFFCAEED7),
        iconColor: Color(0xFF1E8E4A),
        textColor: Color(0xFF145A32),
        shadowColor: Color(0x1F1E8E4A),
      );
    }

    if (message.contains('失败') ||
        message.contains('错误') ||
        message.contains('未') ||
        message.contains('缺少')) {
      return const _MessageStyle(
        icon: Icons.error_rounded,
        backgroundColor: Color(0xFFFFEFEA),
        borderColor: Color(0xFFF2A38B),
        iconBackgroundColor: Color(0xFFFAD1C4),
        iconColor: Color(0xFFD44F21),
        textColor: Color(0xFF7A2E12),
        shadowColor: Color(0x24D44F21),
      );
    }

    return const _MessageStyle(
      icon: Icons.info_rounded,
      backgroundColor: Color(0xFFEAF3FF),
      borderColor: Color(0xFF94BDF2),
      iconBackgroundColor: Color(0xFFD5E7FF),
      iconColor: Color(0xFF1E6FD9),
      textColor: Color(0xFF184A8C),
      shadowColor: Color(0x1F1E6FD9),
    );
  }

  void _hideMessageOverlay() {
    _messageTimer?.cancel();
    _messageTimer = null;
    _messageOverlay?.remove();
    _messageOverlay = null;
  }

  Future<void> _handleClose() async {
    if (_isLoading) {
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认终止查询'),
          content: const Text('当前正在查询重复体检档案，是否终止查询并关闭页面？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续查询'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('终止并关闭'),
            ),
          ],
        ),
      );
      if (shouldClose == true && mounted) {
        _cancelToken.cancel();
        setState(() => _isLoading = false);
        // 等待下一帧 rebuild 后 PopScope 的 canPop 变为 true，再执行 pop
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickDate({
    required DateTime initialDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');

    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isLoading) {
          _handleClose();
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: SizedBox(
        width: 980,
        height: 680,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '筛选重复体检档案',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '共 ${_groups.length} 组重复身份证',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _handleClose,
                    icon: const Icon(Icons.close),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildDateField(
                    label: '开始日期',
                    value: dateFormat.format(_startDate),
                    onTap: () => _pickDate(
                      initialDate: _startDate,
                      onSelected: (date) => setState(() => _startDate = date),
                    ),
                  ),
                  _buildDateField(
                    label: '结束日期',
                    value: dateFormat.format(_endDate),
                    onTap: () => _pickDate(
                      initialDate: _endDate,
                      onSelected: (date) => setState(() => _endDate = date),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: '关键词',
                        hintText: '支持姓名或身份证关键词',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _search,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: const Text('搜索'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _groups.isEmpty
                      ? Center(
                          child: Text(
                            _isLoading
                                ? (_loadingMessage ?? '正在查询重复体检档案...')
                                : (_hasSearched ? '未查询到重复体检档案' : '请设置条件后点击“搜索”开始查询'),
                            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          itemCount: _groups.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            return _buildGroupCard(_groups[index], index + 1);
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '当前仅显示重复档案，单条身份证记录已自动剔除',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _handleClose,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_groups.isEmpty) {
                        _showMessage('当前没有可带回页面的重复体检数据，请先执行搜索并确认结果');
                        return;
                      }

                      Navigator.of(context).pop(
                        DuplicateExamFilterResult(
                          groups: _groups,
                          startDate: _startDate,
                          endDate: _endDate,
                          keyword: _keywordController.text.trim(),
                        ),
                      );
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 170,
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(value),
        ),
      ),
    );
  }

  Widget _buildGroupCard(DuplicateExamGroup group, int index) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7E2EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '第 $index 组',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    '身份证：${group.idCard}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${group.duplicateCount}条',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red[700],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ...group.records.map((record) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      '${DateFormat('yyyy-MM-dd').format(record.examDate)}  ${record.name}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${record.gender} / ${record.age}岁',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: SelectableText(
                      record.idCard,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MessageStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color shadowColor;

  const _MessageStyle({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.shadowColor,
  });
}
