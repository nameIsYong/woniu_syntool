import '../../../models/login_info.dart';
import '../../../services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/physical_merge_auth_state.dart';
import '../models/physical_smart_merge_models.dart';

class PhysicalMergeAuthService {
  const PhysicalMergeAuthService();

  static const String _servicePackageUpdated = '1970-01-01 00:00:00';
  static const String _savePhysicalUserAgent = 'os=2;ver=1;ctype=2;imei=tool';

  Future<PhysicalMergeAuthState> login({
    required String account,
    required String password,
  }) async {
    final loginInfo = await AuthService.login(account, password);
    _ensureSuccess(loginInfo);

    return PhysicalMergeAuthState(
      token: loginInfo.token,
      authToken: loginInfo.authToken,
      institutionName: loginInfo.institutionName,
      account: loginInfo.account,
    );
  }

  /// 获取服务包ID。
  /// 当前保存流程仅依赖第一个服务包ID，后续真实保存接口会继续复用该能力。
  Future<int> fetchServicePackageId({
    required String token,
  }) async {
    final uri = Uri.parse(
      'http://wnjk.2woniu.cn/wnjkapp/spkg/cache?updated=${Uri.encodeQueryComponent(_servicePackageUpdated)}',
    );

    final response = await http.get(
      uri,
      headers: {
        'token': token,
        'Accept': '*/*',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('获取服务包失败：HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    final status = jsonData['status'];
    if (status != 0) {
      throw Exception(jsonData['msg']?.toString() ?? '获取服务包失败');
    }

    final data = jsonData['data'];
    if (data is! List || data.isEmpty) {
      throw Exception('获取服务包失败：返回数据为空');
    }

    final firstItem = data.first;
    if (firstItem is! Map<String, dynamic>) {
      throw Exception('获取服务包失败：返回数据格式不正确');
    }

    final servicePackageId = firstItem['id'];
    if (servicePackageId is! int) {
      throw Exception('获取服务包失败：服务包ID缺失');
    }

    return servicePackageId;
  }

  /// 提交体检保存。
  /// 保存成功时接口返回 status=0，否则使用 msg 作为失败原因。
  Future<void> savePhysicalRecord({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('http://jk.2woniu.cn/wnjkapp/followup/phy/save/record');

print("假数据：保存成功------");
    // final response = await http.post(
    //   uri,
    //   headers: {
    //     'token': token,
    //     'PP-User-Agent': _savePhysicalUserAgent,
    //     'Accept': '*/*',
    //     'Content-Type': 'application/json',
    //   },
    //   body: json.encode(payload),
    // );

    // if (response.statusCode != 200) {
    //   throw Exception('保存体检失败：HTTP ${response.statusCode}');
    // }

    // final jsonData = json.decode(response.body) as Map<String, dynamic>;
    // final status = jsonData['status'];
    // if (status != 0) {
    //   throw Exception(jsonData['msg']?.toString() ?? '保存体检失败');
    // }
  }

  /// 删除体检数据接口预留。
  /// 当前先返回固定失败结果，便于智能合并流程串联并保留后续接入真实接口的入口。
  Future<SmartMergeDeleteResult> deletePhysicalRecord({
    required String token,
    required String recordId,
  }) async {
    if (token.isEmpty || recordId.isEmpty) {
      return const SmartMergeDeleteResult(
        success: false,
        message: '删除体检失败：缺少必要参数',
      );
    }

    return const SmartMergeDeleteResult(
      success: false,
      message: '删除接口未接入，需后续人工处理',
    );
  }

  void _ensureSuccess(LoginInfo loginInfo) {
    if (!loginInfo.success || loginInfo.token.isEmpty) {
      throw Exception(loginInfo.error.isNotEmpty ? loginInfo.error : '登录失败');
    }
  }
}
