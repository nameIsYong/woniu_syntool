import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../util/map_extension.dart';
import '../models/upload_screening_models.dart';

class UploadScreeningQueryService {
  static const String _listUrl =
      'http://bmg.2woniu.cn/bmanage/publichealth/screening/list';

  Future<ScreeningQueryPageResult> queryPage({
    required String token,
    required int page,
    required int size,
    required DateTime startDate,
    required DateTime endDate,
    required ScreeningSyncStatus syncStatus,
  }) async {
    final response = await http.post(
      Uri.parse(_listUrl),
      headers: <String, String>{
        'token': token,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body: <String, String>{
        'page': '$page',
        'size': '$size',
        'startScreeningDate': UploadScreeningFormatters.formatDate(startDate),
        'endScreeningDate': UploadScreeningFormatters.formatDate(endDate),
        'syncStatus': syncStatus.label,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('健康筛查查询失败：HTTP ${response.statusCode}');
    }

    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    final status = jsonMap.intVal('status');
    if (status != 0) {
      throw Exception(
        jsonMap.strVal('msg').isNotEmpty
            ? jsonMap.strVal('msg')
            : '健康筛查查询失败，状态码：$status',
      );
    }

    final data = jsonMap.mapVal('data');
    final pageSize = data.intVal('pageSize');
    final pageNo = data.intVal('pageNo');
    final total = data.intVal('total');
    final results = data.listVal('results');
    final records = <UploadScreeningRecord>[];

    for (final dynamic item in results) {
      if (item is! Map) {
        continue;
      }
      records.add(
        UploadScreeningRecord(
          id: item.intVal('id'),
          name: item.strVal('name').trim(),
          residentHealthRecordId: item.strVal('residentHealthRecordId').trim(),
          idCard: item.strVal('idCard').trim(),
          screeningDate: UploadScreeningFormatters.tryParseTimestamp(
            item['screeningDate'],
          ),
          bodyTemperature: UploadScreeningFormatters.tryParseDouble(
            item['bodyTemperature'],
          ),
          heartRate: UploadScreeningFormatters.tryParseDouble(item['heartRate']),
          respiratoryRate: UploadScreeningFormatters.tryParseDouble(
            item['respiratoryRate'],
          ),
          spb: UploadScreeningFormatters.tryParseDouble(item['spb']),
          dpb: UploadScreeningFormatters.tryParseDouble(item['dpb']),
          height: UploadScreeningFormatters.tryParseDouble(item['height']),
          weight: UploadScreeningFormatters.tryParseDouble(item['weight']),
          waistline: UploadScreeningFormatters.tryParseDouble(item['waistline']),
          bloodSugar: UploadScreeningFormatters.tryParseDouble(item['bloodSugar']),
          randomBloodGlucose: UploadScreeningFormatters.tryParseDouble(
            item['randomBloodGlucose'],
          ),
          remark: item.strVal('remark').trim(),
          thirdSfysName: item.strVal('thirdSfysName').trim(),
          thirdSfysId: item.strVal('thirdSfysId').trim(),
          nextScreeningDate: UploadScreeningFormatters.tryParseTimestamp(
            item['nextScreeningDate'],
          ),
          syncStatus: syncStatus,
        ),
      );
    }

    return ScreeningQueryPageResult(
      pageNo: pageNo,
      pageSize: pageSize,
      total: total,
      records: records,
    );
  }
}

class ScreeningQueryPageResult {
  const ScreeningQueryPageResult({
    required this.pageNo,
    required this.pageSize,
    required this.total,
    required this.records,
  });

  final int pageNo;
  final int pageSize;
  final int total;
  final List<UploadScreeningRecord> records;
}
