class DuplicateExamSearchParams {
  final DateTime startDate;
  final DateTime endDate;
  final String keyword;

  const DuplicateExamSearchParams({
    required this.startDate,
    required this.endDate,
    required this.keyword,
  });
}

class DuplicateExamRecord {
  final String recordId;
  final DateTime examDate;
  final String name;
  final String gender;
  final int age;
  final String idCard;

  DuplicateExamRecord({
    required this.recordId,
    required this.examDate,
    required this.name,
    required this.gender,
    required this.age,
    required this.idCard,
  });
}

class DuplicateExamGroup {
  final String idCard;
  final List<DuplicateExamRecord> records;

  DuplicateExamGroup({
    required this.idCard,
    required this.records,
  });

  int get duplicateCount => records.length;

  /// 左侧重复体检列表的显示姓名。
  /// 同组理论上应为同一人，优先取第一条非空姓名。
  String get displayName {
    for (final record in records) {
      final name = record.name.trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return '未知';
  }
}

class DuplicateExamFilterResult {
  final List<DuplicateExamGroup> groups;
  final DateTime startDate;
  final DateTime endDate;
  final String keyword;

  DuplicateExamFilterResult({
    required this.groups,
    required this.startDate,
    required this.endDate,
    required this.keyword,
  });
}
