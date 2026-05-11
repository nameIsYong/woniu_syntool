import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/login_info.dart';
import '../../../services/auth_service.dart';
import '../models/archives_model.dart';
import '../models/archives_merge_auth_state.dart';

class ArchivesMergeAuthService {
  const ArchivesMergeAuthService();

  static const String _servicePackageUpdated = '1970-01-01 00:00:00';

  Future<ArchivesMergeAuthState> login({
    required String account,
    required String password,
  }) async {
    final loginInfo = await AuthService.login(account, password);
    _ensureSuccess(loginInfo);

    return ArchivesMergeAuthState(
      token: loginInfo.token,
      authToken: loginInfo.authToken,
      institutionName: loginInfo.institutionName,
      account: loginInfo.account,
    );
  }

  /// 获取服务包ID
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

  /// 获取当前登录账号绑定的云平台账号信息
  Future<ThirdAccountInfo> fetchThirdAccountInfo({
    required String token,
  }) async {
    final uri = Uri.parse('https://wnjk.2woniu.cn/wnjkapp/doctor/getThirdInfo');

    final response = await http.get(
      uri,
      headers: {
        'token': token,
        'Accept': '*/*',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('获取云平台账号信息失败：HTTP ${response.statusCode}');
    }

    final jsonData = json.decode(response.body) as Map<String, dynamic>;
    final status = jsonData['status'];
    if (status != 0) {
      throw Exception(jsonData['msg']?.toString() ?? '获取云平台账号信息失败');
    }

    final data = jsonData['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('获取云平台账号信息失败：返回数据格式不正确');
    }

    final info = ThirdAccountInfo(
      thirdUserId: data['thirdUserId']?.toString() ?? '',
      thirdUserName: data['thirdUserName']?.toString() ?? '',
      thirdOrgId: data['thirdOrgId']?.toString() ?? '',
      thirdOrgName: data['thirdOrgName']?.toString() ?? '',
    );

    if (info.thirdUserId.isEmpty ||
        info.thirdUserName.isEmpty ||
        info.thirdOrgId.isEmpty ||
        info.thirdOrgName.isEmpty) {
      throw Exception('获取云平台账号信息失败：关键字段缺失');
    }

    return info;
  }

  void _ensureSuccess(LoginInfo loginInfo) {
    if (!loginInfo.success || loginInfo.token.isEmpty) {
      throw Exception(loginInfo.error.isNotEmpty ? loginInfo.error : '登录失败');
    }
  }
}
