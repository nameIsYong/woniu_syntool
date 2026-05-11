import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/upload_screening_models.dart';

class DaIdResult {
  const DaIdResult({
    required this.daId,
    required this.message,
  });

  final String? daId;
  final String message;
}

class CloudUploadResult {
  const CloudUploadResult({
    required this.success,
    required this.message,
    this.responseBody,
  });

  final bool success;
  final String message;
  final dynamic responseBody;
}

class UploadScreeningCloudService {
  static const String _archiveUrl =
      'https://ehr.scwjxx.cn/ehrc/ehr/jkda/get/paging/simple';
  static const String _uploadUrl = 'https://ehr.scwjxx.cn/ehrc/ehr/jksc/create';
  static const String _frontUrl = 'http://223.85.21.172:99/index.html';
  final Random _random = Random();

  Duration nextDelay() {
    final seconds = _random.nextInt(4) + 1;
    return Duration(seconds: seconds);
  }

  Future<DaIdResult> fetchDaId({
    required String idCard,
    required String areaCode,
    required ParsedCloudHeaders headers,
  }) async {
    final normalizedAreaCode = areaCode.trim();
    final uri = Uri.parse(_archiveUrl).replace(
      queryParameters: <String, String>{
        'total': '0',
        'pageNumber': '1',
        'current': '1',
        'pageSize': '14',
        'area': '',
        'keyword': idCard,
        'daztCode': '10',
        'qyCsConditionCondition': '=',
        '_type': 'area',
        'areaId': normalizedAreaCode,
        'rbh': normalizedAreaCode,
        'wgId': '',
        'qhId': normalizedAreaCode,
        'keywordType': 'zjhm',
        'zrysIds': '',
        'nlBeginType': '年',
        'nlEndType': '年',
      },
    );

    final response = await http.get(
      uri,
      headers: _buildRequestHeaders(headers, contentType: null),
    );

    if (response.statusCode != 200) {
      return DaIdResult(
        daId: null,
        message: '获取 daId 失败：HTTP ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded is Map<String, dynamic>) {
      final code = _asInt(decoded['code']);
      if (code != null && code != 200) {
        return DaIdResult(
          daId: null,
          message: _pickMessage(decoded, fallback: '获取 daId 失败'),
        );
      }

      final total = _extractArchiveTotal(decoded);
      if (total == 0) {
        return const DaIdResult(
          daId: null,
          message: '未查询到该用户',
        );
      }
    }

    final firstRecord = _extractFirstArchiveRecord(decoded);
    if (firstRecord == null) {
      return const DaIdResult(
        daId: null,
        message: '未在云平台响应中找到档案记录',
      );
    }

    final daId = (firstRecord['daId'] ?? '').toString().trim();
    if (daId.isEmpty) {
      return const DaIdResult(
        daId: null,
        message: '云平台返回的首条档案没有 daId',
      );
    }

    return DaIdResult(
      daId: daId,
      message: '匹配成功，已取第 1 条档案',
    );
  }

  Future<CloudUploadResult> uploadRecord({
    required PreparedUploadItem item,
    required ParsedCloudHeaders headers,
  }) async {
    final response = await http.post(
      Uri.parse(_uploadUrl),
      headers: _buildRequestHeaders(headers, contentType: 'application/json'),
      body: json.encode(_buildPayload(item)),
    );

    dynamic parsedBody = response.body;
    try {
      parsedBody = json.decode(response.body);
    } catch (_) {}

    if (response.statusCode != 200) {
      return CloudUploadResult(
        success: false,
        message: '上传失败：HTTP ${response.statusCode}',
        responseBody: parsedBody,
      );
    }

    final success = parsedBody is Map<String, dynamic> && parsedBody['success'] == true;
    if (!success) {
      final message = parsedBody is Map<String, dynamic>
          ? ((parsedBody['msg'] ?? parsedBody['message'] ?? '云平台业务返回失败').toString())
          : '云平台业务返回失败';
      return CloudUploadResult(
        success: false,
        message: message,
        responseBody: parsedBody,
      );
    }

    return CloudUploadResult(
      success: true,
      message: '上传成功',
      responseBody: parsedBody,
    );
  }

  Map<String, String> _buildRequestHeaders(
    ParsedCloudHeaders parsedHeaders, {
    required String? contentType,
  }) {
    final headers = <String, String>{
      'Accept': parsedHeaders.headers['Accept'] ?? 'application/json, text/plain, */*',
      'Accept-Language': parsedHeaders.headers['Accept-Language'] ?? 'zh-CN,zh-Hans;q=0.9',
      'accessToken': parsedHeaders.headers['accessToken'] ?? '',
      'accessToken2': parsedHeaders.headers['accessToken2'] ?? '',
      'Cookie': parsedHeaders.headers['Cookie'] ?? '',
      'ids': parsedHeaders.headers['ids'] ?? 'web',
      'Mdw-Arwwr-Zamw': parsedHeaders.headers['Mdw-Arwwr-Zamw'] ?? '',
      'Pnj-Wwsda-Efja': parsedHeaders.headers['Pnj-Wwsda-Efja'] ?? '',
      'Referer': parsedHeaders.headers['Referer'] ?? '',
      'User-Agent': parsedHeaders.headers['User-Agent'] ?? '',
    };

    final optionalKeys = <String>[
      'Accept-Encoding',
      'Origin',
      'Priority',
      'Sec-Fetch-Dest',
      'Sec-Fetch-Mode',
      'Sec-Fetch-Site',
    ];
    for (final key in optionalKeys) {
      final value = parsedHeaders.headers[key];
      if (value != null && value.trim().isNotEmpty) {
        headers[key] = value;
      }
    }
    if (contentType != null) {
      headers['Content-Type'] = contentType;
    }
    return headers;
  }

  Map<String, dynamic>? _extractFirstArchiveRecord(dynamic decoded) {
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
      return decoded.first as Map<String, dynamic>;
    }
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final queue = <dynamic>[
      decoded['rows'],
      decoded['records'],
      decoded['list'],
      decoded['data'],
    ];
    for (final candidate in queue) {
      if (candidate is List && candidate.isNotEmpty && candidate.first is Map<String, dynamic>) {
        return candidate.first as Map<String, dynamic>;
      }
      if (candidate is Map<String, dynamic>) {
        for (final nestedValue in candidate.values) {
          if (nestedValue is List &&
              nestedValue.isNotEmpty &&
              nestedValue.first is Map<String, dynamic>) {
            return nestedValue.first as Map<String, dynamic>;
          }
        }
      }
    }
    return null;
  }

  int? _extractArchiveTotal(Map<String, dynamic> decoded) {
    final directData = decoded['data'];
    if (directData is Map<String, dynamic>) {
      return _asInt(directData['total']);
    }
    return null;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _pickMessage(
    Map<String, dynamic> decoded, {
    required String fallback,
  }) {
    for (final key in const <String>['message', 'detailMessage', 'msg']) {
      final value = decoded[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  Map<String, dynamic> _buildPayload(PreparedUploadItem item) {
    final detail = item.record;
    final payload = <String, dynamic>{
      'daId': item.daId?.trim(),
      'frontUrl': _frontUrl,
    };

    void putNumber(String key, double? value) {
      if (value != null) {
        payload[key] = value;
      }
    }

    void putText(String key, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        payload[key] = trimmed;
      }
    }

    void putDate(String key, int? timestamp) {
      final text = UploadScreeningFormatters.formatTimestamp(timestamp);
      if (text.isNotEmpty) {
        payload[key] = text;
      }
    }

    putDate('sfrq', detail.screeningDate);
    putNumber('tw', detail.bodyTemperature);
    putNumber('ml', detail.heartRate);
    putNumber('hxpl', detail.respiratoryRate);
    putNumber('ssy', detail.spb);
    putNumber('szy', detail.dpb);
    putNumber('sg', detail.height);
    putNumber('tz', detail.weight);
    putNumber('yw', detail.waistline);
    putNumber('kfxtz', detail.bloodSugar);
    putNumber('sjxt', detail.randomBloodGlucose);
    putText('bz', detail.remark);
    putText('sfysName', detail.thirdSfysName);
    putText('sfysId', detail.thirdSfysId);
    putDate('xcsfrq', detail.nextScreeningDate);

    final bmi = _computeBmi(detail.height, detail.weight);
    if (bmi != null) {
      payload['tzzs'] = bmi;
    }
    return payload;
  }

  String? _computeBmi(double? height, double? weight) {
    if (height == null || weight == null || height <= 0) {
      return null;
    }
    final meter = height / 100;
    if (meter <= 0) {
      return null;
    }
    final bmi = weight / (meter * meter);
    return bmi.toStringAsFixed(1);
  }
}
