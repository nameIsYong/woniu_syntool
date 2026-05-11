import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/archives_physical_record.dart';
import '../models/archives_model.dart';
import '../models/archives_search_result.dart';

class ArchivesSearchService {
  const ArchivesSearchService();

  static const int _defaultPhysicalRecordPage = 1;
  static const int _defaultPhysicalRecordSize = 20;

  /// 搜索档案列表
  Future<List<ArchivesSearchItem>> searchArchives({
    required String token,
    required String keyword,
    required int status,
    int pageNo = 1,
    int pageSize = 10,
  }) async {
    // 生产环境
    final uri = Uri.parse(
      'http://bmg.2woniu.cn/bmanage/publichealth/healthrecord/list'
      '?unRegionCode=0'
      '&keyword=${Uri.encodeComponent(keyword)}'
      '&pageNo=$pageNo'
      '&pageSize=$pageSize'
      '&status=$status',
    );

  //开发环境
    //  final uri = Uri.parse(
    //   'http://bmg.test.2woniu.cn:6969/bmanage/publichealth/healthrecord/list'
    //   '?unRegionCode=0'
    //   '&keyword=${Uri.encodeComponent(keyword)}'
    //   '&pageNo=$pageNo'
    //   '&pageSize=$pageSize'
    //   '&status=$status',
    // );

    final response = await http.get(
      uri,
      headers: {'token': token, 'Accept': '*/*'},
    );

    if (response.statusCode != 200) {
      throw Exception('请求失败：HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    final statusCode = jsonData['status'];
    if (statusCode != 0) {
      throw Exception(jsonData['msg']?.toString() ?? '查询失败');
    }

    final data = jsonData['data'] as Map<String, dynamic>?;
    final results = data?['results'] as List<dynamic>? ?? [];

    return results.map((e) => ArchivesSearchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 查询档案详情
  Future<ArchivesDetail> fetchArchivesDetail({
    required String token,
    required String residentHealthRecordId,
  }) async {
    //生产环境
    final uri = Uri.parse(
      'http://wnjk.2woniu.cn/wnjkapp/resident/archives/detail?residentHealthRecordId=$residentHealthRecordId',
    );
    //开发环境
//  final uri = Uri.parse(
//       'http://jk.test.2woniu.cn:6969/wnjkapp/resident/archives/detail?residentHealthRecordId=$residentHealthRecordId',
//     );
    final response = await http.get(
      uri,
      headers: {'token': token, 'Accept': '*/*'},
    );

    if (response.statusCode != 200) {
      throw Exception('请求失败：HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    final statusCode = jsonData['status'];
    if (statusCode != 0) {
      throw Exception(jsonData['msg']?.toString() ?? '查询档案详情失败');
    }

    final data = jsonData['data'] as Map<String, dynamic>?;
    final yptData = data?['yptData'] as Map<String, dynamic>? ?? {};
    final model = ArchivesModel.fromJson(yptData);

    return ArchivesDetail(
      residentHealthRecordId: residentHealthRecordId,
      model: model,
    );
  }

  /// 查询指定档案今年的体检列表。
  ///
  /// 当前按需求固定查询第 1 页、每页 20 条，只预留接口供后续接入使用。
  Future<List<ArchivesPhysicalRecord>> fetchCurrentYearPhysicalRecords({
    required String token,
    required String residentHealthRecordId,
  }) async {
    final uri = Uri.parse('https://wnjk.2woniu.cn/wnjkapp/followup/phy/list');
    final response = await http.post(
      uri,
      headers: {
        'token': token,
        'Accept': '*/*',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'page': _defaultPhysicalRecordPage,
        'residentHealthRecordId': residentHealthRecordId,
        'size': _defaultPhysicalRecordSize,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('查询体检列表失败：HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body);
    if (jsonData is! Map<String, dynamic>) {
      throw Exception('查询体检列表失败：返回数据格式错误');
    }

    final statusCode = jsonData['status'];
    if (statusCode != 0) {
      throw Exception(jsonData['msg']?.toString() ?? '查询体检列表失败');
    }

    final data = jsonData['data'] as List<dynamic>? ?? const [];
    return data
        .whereType<Map>()
        .map((item) => ArchivesPhysicalRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
