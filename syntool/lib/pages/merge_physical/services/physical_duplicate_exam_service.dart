import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/physical_duplicate_exam_models.dart';

/// 用于取消长时间分页查询的取消令牌。
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() => _isCancelled = true;
}

class PhysicalDuplicateExamService {
  const PhysicalDuplicateExamService();

  static const String _recordListUrl =
      'http://bmg.2woniu.cn/bmanage/publichealth/service/record/1/list';

  /// 默认分页大小
  static const int _defaultPageSize = 80;

  /// 查询体检记录后，前端按身份证分组，仅保留重复档案。
  ///
  /// 当前使用固定分页大小 [80]，若接口返回多页数据，则串行逐页查询
  /// 全部数据后，汇总再统一进行分组与去重。
  ///
  /// [onProgress] 在每次查询到新一页数据后回调，参数为 (currentPage, totalPages)。
  Future<List<DuplicateExamGroup>> searchDuplicateExams({
    required String token,
    required DuplicateExamSearchParams params,
    void Function(int currentPage, int totalPages)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (token.isEmpty) {
      throw Exception('未获取到登录 token');
    }

    final allResults = <Map<String, dynamic>>[];
    int currentPage = 1;
    int? totalPages;

    while (true) {
      if (cancelToken?.isCancelled == true) {
        throw Exception('查询已取消');
      }

      final uri = Uri.parse(_recordListUrl).replace(
        queryParameters: {
          'unRegionCode': '0',
          'peStart': DateFormat('yyyy-MM-dd').format(params.startDate),
          'peEnd': DateFormat('yyyy-MM-dd').format(params.endDate),
          'keyword': params.keyword.trim(),
          'pageNo': currentPage.toString(),
          'pageSize': _defaultPageSize.toString(),
          'nodeId': '1',
          'isUpload': '2',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'token': token,
          'User-Agent': 'Apifox/1.0.0 (https://apifox.com)',
          'Accept': '*/*',
          'Host': 'bmg.2woniu.cn',
          'Connection': 'keep-alive',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('查询重复体检失败：HTTP ${response.statusCode}');
      }

      final jsonData = json.decode(response.body);
      if (jsonData is! Map<String, dynamic>) {
        throw Exception('查询重复体检失败：返回数据格式错误');
      }

      final status = jsonData['status'];
      if (status != 0) {
        final message = jsonData['msg']?.toString();
        throw Exception(message?.isNotEmpty == true ? message! : '查询重复体检失败');
      }

      final data = jsonData['data'];
      if (data is! Map<String, dynamic>) {
        break;
      }

      final results = data['results'];
      if (results is List) {
        allResults.addAll(
          results.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      }

      final total = _parseTotal(data['total']);
      totalPages = (total / _defaultPageSize).ceil();
      if (totalPages < 1) totalPages = 1;

      onProgress?.call(currentPage, totalPages);

      if (currentPage >= totalPages) {
        break;
      }

      currentPage++;
    }

    final records = allResults
        .map((item) => _parseRecord(item))
        .whereType<DuplicateExamRecord>()
        .toList()
      ..sort((a, b) => b.examDate.compareTo(a.examDate));

    final Map<String, List<DuplicateExamRecord>> groupMap = {};
    for (final record in records) {
      if (record.idCard.isEmpty) {
        continue;
      }
      groupMap.putIfAbsent(record.idCard, () => []).add(record);
    }

    final groups = groupMap.entries
        .where((entry) => entry.value.length > 1)
        .map(
          (entry) => DuplicateExamGroup(
            idCard: entry.key,
            records: entry.value
              ..sort((a, b) => b.examDate.compareTo(a.examDate)),
          ),
        )
        .toList()
      ..sort((a, b) {
        final countCompare = b.duplicateCount.compareTo(a.duplicateCount);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.idCard.compareTo(b.idCard);
      });

    return groups;
  }

  int _parseTotal(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DuplicateExamRecord? _parseRecord(Map<String, dynamic> item) {
    final rhrRaw = item['rhr'];
    final rhr = rhrRaw is Map
        ? Map<String, dynamic>.from(rhrRaw)
        : <String, dynamic>{};

    final idCard = rhr['idCard']?.toString().trim() ?? '';
    if (idCard.isEmpty) {
      return null;
    }

    return DuplicateExamRecord(
      recordId: item['id']?.toString() ?? '',
      examDate: _parseExamDate(item['timeNode']?.toString()),
      name: rhr['name']?.toString() ?? '',
      gender: _parseGender(rhr['gender']),
      age: _parseInt(rhr['ageForYear']),
      idCard: idCard,
    );
  }

  DateTime _parseExamDate(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return DateTime.now();
    }

    try {
      return DateTime.parse(rawValue);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(rawValue);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  String _parseGender(dynamic genderValue) {
    final gender = _parseInt(genderValue);
    switch (gender) {
      case 1:
        return '男';
      case 2:
        return '女';
      default:
        return '-';
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
