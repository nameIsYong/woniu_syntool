import 'package:intl/intl.dart';

enum ScreeningSyncStatus {
  unsynced('未同步'),
  failed('同步失败');

  const ScreeningSyncStatus(this.label);

  final String label;
}

enum UploadPhase {
  idle,
  ready,
  resolvingDaId,
  uploading,
  paused,
  completed,
}

class UploadScreeningRecord {
  UploadScreeningRecord({
    required this.id,
    required this.name,
    required this.residentHealthRecordId,
    required this.idCard,
    required this.screeningDate,
    required this.bodyTemperature,
    required this.heartRate,
    required this.respiratoryRate,
    required this.spb,
    required this.dpb,
    required this.height,
    required this.weight,
    required this.waistline,
    required this.bloodSugar,
    required this.randomBloodGlucose,
    required this.remark,
    required this.thirdSfysName,
    required this.thirdSfysId,
    required this.nextScreeningDate,
    required this.syncStatus,
  });

  final int id;
  final String name;
  final String residentHealthRecordId;
  final String idCard;
  final int? screeningDate;
  final double? bodyTemperature;
  final double? heartRate;
  final double? respiratoryRate;
  final double? spb;
  final double? dpb;
  final double? height;
  final double? weight;
  final double? waistline;
  final double? bloodSugar;
  final double? randomBloodGlucose;
  final String remark;
  final String thirdSfysName;
  final String thirdSfysId;
  final int? nextScreeningDate;
  final ScreeningSyncStatus syncStatus;

  String get screeningDateText => UploadScreeningFormatters.formatTimestamp(
        screeningDate,
      );

  String get nextScreeningDateText => UploadScreeningFormatters.formatTimestamp(
        nextScreeningDate,
      );
}

class CsvUploadedRecord {
  CsvUploadedRecord({
    required this.name,
    required this.gender,
    required this.idCardMasked,
    required this.screeningDate,
    required this.columns,
  });

  final String name;
  final String gender;
  final String idCardMasked;
  final String screeningDate;
  final List<String> columns;
}

class ScreeningQuerySummary {
  const ScreeningQuerySummary({
    this.unsyncedCount = 0,
    this.failedCount = 0,
    this.mergedCount = 0,
    this.deduplicatedCount = 0,
  });

  final int unsyncedCount;
  final int failedCount;
  final int mergedCount;
  final int deduplicatedCount;
}

class ParsedCloudHeaders {
  ParsedCloudHeaders({
    required this.headers,
    required this.rawText,
    required this.missingRequiredKeys,
    required this.requestMeta,
  });

  static const List<String> requiredKeys = <String>[
    'accessToken',
    'Cookie',
    'ids',
    'Mdw-Arwwr-Zamw',
    'Pnj-Wwsda-Efja',
    'Referer',
    'User-Agent',
  ];

  final Map<String, String> headers;
  final String rawText;
  final List<String> missingRequiredKeys;
  final Map<String, String> requestMeta;

  bool get isValid => missingRequiredKeys.isEmpty;
}

class PreparedUploadItem {
  PreparedUploadItem({
    required this.record,
    required this.matchedCsvRecord,
    this.daId,
    this.daIdResolvedAt,
    this.uploadedAt,
    this.uploadSucceeded = false,
    this.failureReason,
  });

  final UploadScreeningRecord record;
  final CsvUploadedRecord? matchedCsvRecord;
  String? daId;
  DateTime? daIdResolvedAt;
  DateTime? uploadedAt;
  bool uploadSucceeded;
  String? failureReason;

  String get displayIdCard {
    if (record.idCard.length < 8) {
      return record.idCard;
    }
    return '${record.idCard.substring(0, 6)}****${record.idCard.substring(record.idCard.length - 4)}';
  }

  PreparedUploadItem copyForFailure(String reason) {
    return PreparedUploadItem(
      record: record,
      matchedCsvRecord: matchedCsvRecord,
      daId: daId,
      daIdResolvedAt: daIdResolvedAt,
      uploadedAt: uploadedAt,
      uploadSucceeded: false,
      failureReason: reason,
    );
  }
}

class UploadFailureRecord {
  const UploadFailureRecord({
    required this.item,
    required this.reason,
    required this.occurredAt,
  });

  final PreparedUploadItem item;
  final String reason;
  final DateTime occurredAt;
}

class DelayLog {
  const DelayLog({
    required this.message,
    required this.createdAt,
  });

  final String message;
  final DateTime createdAt;
}

class UploadProgressSnapshot {
  const UploadProgressSnapshot({
    this.daIdProcessed = 0,
    this.daIdTotal = 0,
    this.uploadProcessed = 0,
    this.uploadTotal = 0,
    this.uploadSucceeded = 0,
  });

  final int daIdProcessed;
  final int daIdTotal;
  final int uploadProcessed;
  final int uploadTotal;
  final int uploadSucceeded;

  bool get hasDaIdProgress => daIdTotal > 0;
  bool get hasUploadProgress => uploadTotal > 0;
}

class QueryProgressSnapshot {
  const QueryProgressSnapshot({
    this.currentStatusLabel = '',
    this.currentPage = 0,
    this.totalPages = 0,
    this.loadedCount = 0,
  });

  final String currentStatusLabel;
  final int currentPage;
  final int totalPages;
  final int loadedCount;

  bool get hasProgress => currentPage > 0;
}

class UploadScreeningFormatters {
  static final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String formatDate(DateTime date) => _dateFormatter.format(date);

  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormatter.format(dateTime);

  static String formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '';
    }
    return _dateFormatter.format(
      DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal(),
    );
  }

  static int? tryParseTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    final parsed = int.tryParse(value.toString());
    return parsed;
  }

  static double? tryParseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}
