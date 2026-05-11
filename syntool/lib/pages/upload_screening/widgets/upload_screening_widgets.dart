import 'package:flutter/material.dart';

import '../models/upload_screening_models.dart';

class UploadScreeningSectionCard extends StatelessWidget {
  const UploadScreeningSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class UploadScreeningSummaryGrid extends StatelessWidget {
  const UploadScreeningSummaryGrid({
    super.key,
    required this.summary,
    required this.pendingCount,
    required this.skippedCount,
    required this.failureCount,
  });

  final ScreeningQuerySummary summary;
  final int pendingCount;
  final int skippedCount;
  final int failureCount;

  @override
  Widget build(BuildContext context) {
    final items = <_SummaryItem>[
      _SummaryItem('未同步', '${summary.unsyncedCount}'),
      _SummaryItem('同步失败', '${summary.failedCount}'),
      _SummaryItem('去重前合计', '${summary.mergedCount}'),
      _SummaryItem('去重后合计', '${summary.deduplicatedCount}'),
      _SummaryItem('待上传', '$pendingCount'),
      _SummaryItem('CSV 排除', '$skippedCount'),
      _SummaryItem('本次失败', '$failureCount'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD8E6FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0),
                        ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class UploadScreeningPendingTable extends StatelessWidget {
  const UploadScreeningPendingTable({
    super.key,
    required this.items,
  });

  final List<PreparedUploadItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('当前没有待上传数据');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('序号')),
          DataColumn(label: Text('姓名')),
          DataColumn(label: Text('身份证号')),
          DataColumn(label: Text('筛查日期')),
          DataColumn(label: Text('健康筛查ID')),
          DataColumn(label: Text('daId')),
          DataColumn(label: Text('状态')),
        ],
        rows: List.generate(
          items.length,
          (index) {
            final item = items[index];
            final status = item.uploadSucceeded
                ? '上传成功'
                : ((item.failureReason ?? '').isNotEmpty
                    ? item.failureReason!
                    : ((item.daId ?? '').isNotEmpty ? '待上传' : '待获取 daId'));
            return DataRow(
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(item.record.name)),
                DataCell(Text(item.record.idCard)),
                DataCell(Text(item.record.screeningDateText)),
                DataCell(Text('${item.record.id}')),
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Text(
                      item.daId ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class UploadScreeningLogPanel extends StatelessWidget {
  const UploadScreeningLogPanel({
    super.key,
    required this.logs,
  });

  final List<DelayLog> logs;

  @override
  Widget build(BuildContext context) {
    final logText = logs.isEmpty
        ? '当前没有过程日志'
        : logs
            .map(
              (log) =>
                  '[${UploadScreeningFormatters.formatDateTime(log.createdAt)}] ${log.message}',
            )
            .join('\n\n');

    return Container(
      height: 300,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: SelectableText(
            logText,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value);

  final String label;
  final String value;
}
