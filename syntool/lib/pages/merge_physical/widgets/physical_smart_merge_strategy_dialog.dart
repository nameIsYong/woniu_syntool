import 'package:flutter/material.dart';

import '../models/physical_smart_merge_models.dart';

class PhysicalSmartMergeStrategyDialog extends StatefulWidget {
  const PhysicalSmartMergeStrategyDialog({super.key});

  @override
  State<PhysicalSmartMergeStrategyDialog> createState() =>
      _PhysicalSmartMergeStrategyDialogState();
}

class _PhysicalSmartMergeStrategyDialogState
    extends State<PhysicalSmartMergeStrategyDialog> {
  bool _autoDeleteAuxiliary = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('智能合并策略'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '系统会按左侧重复体检列表顺序逐人串行处理，每个人处理完成后才继续下一个。',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
              _buildRuleItem('自动选择主数据：优先选择非空节点更多的一条。'),
              _buildRuleItem(
                '若非空节点数量一致，则比较体检日期，日期更新的一条作为主数据。',
              ),
              _buildRuleItem(
                '若体检日期为空、缺失或非法，则优先选择日期有效的一条；两条都无效时选择第一条。',
              ),
              _buildRuleItem('冲突项自动以主数据为准，辅数据冲突值将被舍弃。'),
              _buildRuleItem('某个人处理失败不会中断整体流程，系统会记录结果后继续下一个。'),
              _buildRuleItem('重复体检数量大于 3 的人员会直接跳过，防止误合并。'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD8E4F2)),
                ),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoDeleteAuxiliary,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    '合并保存成功后自动删除辅数据',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    '当前删除接口先按预留假接口执行。若删除失败，会记录到明细中，后续需人工处理。',
                    style: TextStyle(fontSize: 12, height: 1.45),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _autoDeleteAuxiliary = value ?? false;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(
              SmartMergeStrategy(
                autoDeleteAuxiliary: _autoDeleteAuxiliary,
              ),
            );
          },
          child: const Text('开始智能合并'),
        ),
      ],
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 6,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
