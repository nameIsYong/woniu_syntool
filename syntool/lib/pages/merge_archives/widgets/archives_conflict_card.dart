import 'package:flutter/material.dart';
import '../models/archives_merge_item.dart';

class ArchivesConflictCard extends StatelessWidget {
  final MergeItem item;
  final ValueChanged<MergeDecision> onDecisionChanged;
  final VoidCallback onToggleAuxiliary;

  const ArchivesConflictCard({
    super.key,
    required this.item,
    required this.onDecisionChanged,
    required this.onToggleAuxiliary,
  });

  @override
  Widget build(BuildContext context) {
    // 档案合并页运行在 Web 端时，需要支持鼠标拖拽选中文本并复制。
    return SelectionArea(
      child: switch (item.type) {
        MergeItemType.mainOnly || MergeItemType.equal => _buildMainCard(),
        MergeItemType.auxiliaryOnly => _buildAuxiliaryCard(),
        MergeItemType.conflict => _buildConflictCard(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildMainCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.fieldName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                item.mainDisplayValue,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuxiliaryCard() {
    final isCancelled = item.isAuxiliaryCancelled;
    final cardColor = isCancelled ? const Color(0xFFF8F8F8) : Colors.green[50]!;
    final borderColor = isCancelled ? const Color(0xFFE4E4E4) : Colors.green[300]!;
    final tagColor = isCancelled ? const Color(0xFFEEEEEE) : Colors.green[100]!;
    final tagTextColor = isCancelled ? const Color(0xFF9E9E9E) : Colors.green[800]!;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: isCancelled ? const Color(0xFFA8A8A8) : Colors.black87,
    );
    final actionColor = isCancelled ? Colors.blue[700]! : Colors.grey[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: tagColor,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                isCancelled ? '已取消新增' : '新增',
                style: TextStyle(
                  fontSize: 10,
                  color: tagTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(item.fieldName, style: titleStyle),
            ),
            Expanded(
              flex: 4,
              child: Opacity(
                opacity: isCancelled ? 0.38 : 1,
                child: Text(
                  item.auxiliaryDisplayValue,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onToggleAuxiliary,
              style: TextButton.styleFrom(
                visualDensity: const VisualDensity(horizontal: -3, vertical: -4),
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: actionColor,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCancelled ? Icons.restore : Icons.remove_circle_outline,
                    size: 14,
                    color: actionColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    isCancelled ? '恢复新增' : '取消新增',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard() {
    final isResolved = item.isResolved;
    final isMainSelected = item.decision == MergeDecision.keepMain;
    final isAuxSelected = item.decision == MergeDecision.keepAuxiliary;
    final primaryColor = isResolved ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: isResolved ? 1 : 2,
      color: primaryColor[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(
          color: primaryColor[300]!,
          width: isResolved ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: primaryColor[100],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isResolved ? (isMainSelected ? '已选主' : '已选辅') : '冲突',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryColor[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.fieldName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isResolved)
                  Icon(Icons.check_circle, color: Colors.green[600], size: 18),
              ],
            ),
            const SizedBox(height: 8),
            _buildConflictOption(
              label: '主',
              displayValue: item.mainDisplayValue,
              color: Colors.blue,
              isSelected: isMainSelected,
              onTap: () => onDecisionChanged(MergeDecision.keepMain),
            ),
            const SizedBox(height: 6),
            _buildConflictOption(
              label: '辅',
              displayValue: item.auxiliaryDisplayValue,
              color: Colors.orange,
              isSelected: isAuxSelected,
              onTap: () => onDecisionChanged(MergeDecision.keepAuxiliary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictOption({
    required String label,
    required String displayValue,
    required MaterialColor color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color[100] : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color[600]! : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color[600] : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color[600]! : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: color[100],
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Colors.green[600], size: 16),
          ],
        ),
      ),
    );
  }
}
