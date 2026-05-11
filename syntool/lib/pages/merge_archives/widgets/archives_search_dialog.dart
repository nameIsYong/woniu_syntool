import 'package:flutter/material.dart';
import '../models/archives_enum_maps.dart';
import '../models/archives_search_result.dart';

class ArchivesSearchDialog extends StatefulWidget {
  final String title;
  final String token;
  final Future<List<ArchivesSearchItem>> Function({
    required String token,
    required String keyword,
    required int status,
  }) onSearch;
  final ArchivesSearchItem? excludeItem;

  const ArchivesSearchDialog({
    super.key,
    required this.title,
    required this.token,
    required this.onSearch,
    this.excludeItem,
  });

  @override
  State<ArchivesSearchDialog> createState() => _ArchivesSearchDialogState();
}

class _ArchivesSearchDialogState extends State<ArchivesSearchDialog> {
  final TextEditingController _keywordController = TextEditingController();
  int _status = 0;
  bool _isLoading = false;
  String? _errorText;
  List<ArchivesSearchItem> _results = [];
  ArchivesSearchItem? _selected;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _errorText = '请输入关键词';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _results = [];
      _selected = null;
    });

    try {
      final results = await widget.onSearch(
        token: widget.token,
        keyword: keyword,
        status: _status,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _genderText(int? gender) {
    if (gender == 1) return '男';
    if (gender == 2) return '女';
    return '未知';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(
                      labelText: '关键词',
                      hintText: '姓名或身份证号',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<int>(
                    value: _status,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      isDense: true,
                    ),
                    items: archivesStatusOptions.entries.map((e) {
                      return DropdownMenuItem<int>(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _status = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _search,
                  icon: _isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search, size: 18),
                  label: const Text('搜索'),
                ),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty && !_isLoading
                  ? Center(
                      child: Text(
                        _errorText == null ? '请输入关键词后点击搜索' : '未找到数据',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final isExcluded = widget.excludeItem?.id == item.id;
                        final isSelected = _selected?.id == item.id;

                        return ListTile(
                          enabled: !isExcluded,
                          selected: isSelected,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: isExcluded
                              ? Icon(Icons.block, color: Colors.grey[400], size: 20)
                              : isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                  : const Icon(Icons.radio_button_unchecked, size: 20),
                          title: Text(
                            '${item.name} | ${_genderText(item.gender)} | ${item.ageForYear ?? '-'}岁',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isExcluded ? Colors.grey : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            '身份证: ${item.idCard}\n住址: ${item.address}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExcluded ? Colors.grey[400] : Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                          isThreeLine: true,
                          onTap: isExcluded
                              ? null
                              : () {
                                  setState(() {
                                    _selected = item;
                                  });
                                },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
