import 'package:file_selector/file_selector.dart';

import '../models/upload_screening_models.dart';

class UploadScreeningParserService {
  Future<String?> pickCsvContent() async {
    const typeGroup = XTypeGroup(
      label: 'csv',
      extensions: <String>['csv'],
      mimeTypes: <String>['text/csv', 'text/plain'],
      webWildCards: <String>['.csv'],
    );
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null) {
      return null;
    }
    return await file.readAsString();
  }

  List<CsvUploadedRecord> parseCsv(String rawCsv) {
    final sanitized = rawCsv.replaceFirst('\uFEFF', '').trim();
    if (sanitized.isEmpty) {
      throw Exception('CSV 文件内容为空');
    }

    final rows = sanitized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_splitCsvLine)
        .toList();

    if (rows.isEmpty) {
      throw Exception('CSV 文件没有有效数据');
    }

    final startIndex = _isHeaderRow(rows.first) ? 1 : 0;
    final records = <CsvUploadedRecord>[];
    for (var i = startIndex; i < rows.length; i++) {
      final columns = rows[i];
      if (columns.length < 5) {
        continue;
      }
      final name = columns[0].trim();
      final gender = columns[1].trim();
      final idCardMasked = columns[3].trim().toUpperCase();
      final screeningDate = columns[4].trim();
      if (name.isEmpty ||
          gender.isEmpty ||
          idCardMasked.isEmpty ||
          screeningDate.isEmpty) {
        continue;
      }
      records.add(
        CsvUploadedRecord(
          name: name,
          gender: gender,
          idCardMasked: idCardMasked,
          screeningDate: screeningDate,
          columns: columns,
        ),
      );
    }

    if (records.isEmpty) {
      throw Exception('CSV 文件没有解析出有效记录');
    }
    return records;
  }

  ParsedCloudHeaders parseCloudHeaders(String rawText) {
    final headers = <String, String>{};
    final requestMeta = <String, String>{};

    for (final line in rawText.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith(':')) {
        final secondColon = trimmed.indexOf(':', 1);
        if (secondColon > 1) {
          requestMeta[trimmed.substring(0, secondColon)] =
              trimmed.substring(secondColon + 1).trim();
        }
        continue;
      }

      final splitIndex = trimmed.indexOf(':');
      if (splitIndex <= 0) {
        continue;
      }

      final key = trimmed.substring(0, splitIndex).trim();
      final value = trimmed.substring(splitIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      headers[key] = value;
    }

    final missing = ParsedCloudHeaders.requiredKeys
        .where((requiredKey) => (headers[requiredKey] ?? '').trim().isEmpty)
        .toList();

    return ParsedCloudHeaders(
      headers: headers,
      rawText: rawText,
      missingRequiredKeys: missing,
      requestMeta: requestMeta,
    );
  }

  bool isCsvMatched({
    required UploadScreeningRecord record,
    required CsvUploadedRecord csvRecord,
  }) {
    final normalizedName = record.name.trim();
    final csvName = csvRecord.name.trim();
    if (normalizedName != csvName) {
      return false;
    }

    if (!_matchesMaskedIdCard(record.idCard, csvRecord.idCardMasked)) {
      return false;
    }

    if (_genderFromIdCard(record.idCard) != csvRecord.gender.trim()) {
      return false;
    }

    final recordDate = record.screeningDateText;
    return _daysDiff(recordDate, csvRecord.screeningDate.trim()) <= 5;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final isEscapedQuote =
            inQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          i++;
          continue;
        }
        inQuotes = !inQuotes;
        continue;
      }
      if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    result.add(buffer.toString());
    return result;
  }

  bool _isHeaderRow(List<String> row) {
    if (row.isEmpty) {
      return false;
    }
    return row.first.trim() == '姓名' && row.length > 4 && row[1].trim() == '性别';
  }

  bool _matchesMaskedIdCard(String fullIdCard, String maskedIdCard) {
    final normalizedFull = fullIdCard.trim().toUpperCase();
    final normalizedMasked = maskedIdCard.trim().toUpperCase();
    if (!RegExp(r'^\d{17}[\dX]$').hasMatch(normalizedFull)) {
      return false;
    }
    if (!RegExp(r'^\d{14}\*{4}$').hasMatch(normalizedMasked)) {
      return false;
    }
    return normalizedFull.substring(0, 14) == normalizedMasked.substring(0, 14);
  }

  String? _genderFromIdCard(String idCard) {
    final normalized = idCard.trim().toUpperCase();
    if (!RegExp(r'^\d{17}[\dX]$').hasMatch(normalized)) {
      return null;
    }
    final number = int.tryParse(normalized[16]);
    if (number == null) {
      return null;
    }
    return number.isEven ? '女' : '男';
  }

  int _daysDiff(String firstDate, String secondDate) {
    final first = DateTime.tryParse(firstDate);
    final second = DateTime.tryParse(secondDate);
    if (first == null || second == null) {
      return 9999;
    }
    return first.difference(second).inDays.abs();
  }
}
