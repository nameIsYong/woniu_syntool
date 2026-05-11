import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/login_info.dart';
import '../util/map_extension.dart';

class AuthService {
  const AuthService._();
// 生产环境
  static const String _loginUrl = 'http://sign.2woniu.cn/sign/sso/pass';
  static const String _profileUrl =
      'https://wnjk.2woniu.cn/staff/profile/loadAll';
  // // 开发环境
  // static const String _loginUrl = 'http://sign.test.2woniu.cn:6969/sign/sso/pass';
  // static const String _profileUrl =
  //     'https://jk.test.2woniu.cn:6968/staff/profile/loadAll';




  static const Map<int, String> _statusTips = {
    0: 'OK',
    1: '版本过期',
    2: '用户角色和对应的app端不一致',
    3: '请求参数错误',
    4: '访问的数据不存在',
    5: '数据过期',
    6: '权限不足造成的拒绝访问',
    7: '您还没有通过实名认证哟',
    8: '状态被锁定,异常状态',
    9: '系统运行错误',
    10: '操作失败',
    11: '数据已经在系统存在了',
    12: '验证码错误',
    13: '操作太过频繁',
    14: '验证码已过期',
    15: 'token 验证失败',
    16: '数据太长',
    17: '数据类型不对',
    18: '身份验证错误',
    19: '您还没有通过职业认证哟',
    20: '基础家庭医生服务包只能签约一个',
    99: '',
    101: '账号或密码不正确',
    102: '您已经在其他设备登录了',
    103: '该手机号已经绑定',
    104: '您已经认证过了',
    105: '服务包无效',
    106: '认证中',
    107: '设备已经激活了',
    108: '身份证已经被使用',
    109: '设备还未激活了',
    110: '状态不正确',
    200: '居民标签数量已经满了',
  };

  static Future<LoginInfo> login(
    String account,
    String password, {
    String userAuthAgent = 'os=5;client=1;ver=0.0.1;role=2;business=UCMS',
  }) async {
    final normalizedAccount = account.trim();
    final normalizedPassword = password.trim();

    if (normalizedAccount.isEmpty || normalizedPassword.isEmpty) {
      return _failedLoginInfo('请输入账号和密码');
    }

    try {
      final md5Password =
          md5.convert(utf8.encode(normalizedPassword)).toString();

      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {
          'User-Auth-Agent': userAuthAgent,
          'Accept': '*/*',
          'Host': 'sign.2woniu.cn',
          'Connection': 'keep-alive',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'loginId': normalizedAccount,
          'pass': md5Password,
        },
      );

      if (response.statusCode != 200) {
        return _failedLoginInfo('登录请求失败：HTTP ${response.statusCode}');
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      final status = jsonResponse.intVal('status');

      if (status != 0) {
        final message = _statusTips[status];
        final fallback = jsonResponse.strVal('message');
        return _failedLoginInfo(
          (message != null && message.isNotEmpty)
              ? message
              : (fallback.isNotEmpty ? fallback : '登录失败，状态码：$status'),
        );
      }

      final data = jsonResponse.mapVal('data');
      final token = data.strVal('token');
      if (token.isEmpty) {
        return _failedLoginInfo('登录成功但未获取到 token');
      }

      final authToken = data.strVal('authToken');
      final userId = _parseUserIdFromToken(token);
      final profile = await getLoginDetailInfo(token, userId);
      profile.account = normalizedAccount;
      profile.password = normalizedPassword;
      profile.authToken = authToken;

      if (profile.institutionName.isEmpty) {
        profile.institutionName = normalizedAccount;
      }

      return profile;
    } catch (e) {
      return _failedLoginInfo('网络错误: $e');
    }
  }

  static Future<LoginInfo> getLoginDetailInfo(String token, String userId) async {
    try {
      final response = await http.post(
        Uri.parse(_profileUrl),
        headers: {
          'PP-User-Agent': 'os=2;ver=1;ctype=2',
          'Content-Type': 'application/json',
          'token': token,
        },
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode != 200) {
        return _failedLoginInfo('获取机构信息失败：HTTP ${response.statusCode}');
      }

      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      if (jsonResponse.intVal('status') != 0) {
        final status = jsonResponse.intVal('status');
        final fallback = jsonResponse.strVal('message');
        return _failedLoginInfo(
          _statusTips[status] ??
              (fallback.isNotEmpty ? fallback : '获取机构信息失败，状态码：$status'),
        );
      }

      final data = jsonResponse.mapVal('data');
      final doctorInfo = data.mapVal('doctorInfo');
      final institutions = data.listVal('institutions');
      final institutionMap = institutions.isEmpty
          ? <String, dynamic>{}
          : (institutions.first as Map<String, dynamic>);

      final loginInfo = LoginInfo();
      loginInfo.success = true;
      loginInfo.token = token;
      loginInfo.doctorId = userId;
      loginInfo.doctorName = doctorInfo.strVal('nickname');
      loginInfo.areaCode = doctorInfo.strVal('areaCode');
      loginInfo.institutionId = institutionMap.strVal('id');
      loginInfo.institutionName = institutionMap.strVal('name');
      return loginInfo;
    } catch (e) {
      return _failedLoginInfo('网络错误: $e');
    }
  }

  static String parseUserIdFromToken(String token) {
    return _parseUserIdFromToken(token);
  }

  static String _parseUserIdFromToken(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      throw Exception('登录返回的 token 格式不正确');
    }

    final payload = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(payload));
    final payloadMap = json.decode(decoded) as Map<String, dynamic>;
    final userId = payloadMap['id']?.toString() ?? '';

    if (userId.isEmpty) {
      throw Exception('登录成功但未解析到用户信息');
    }

    return userId;
  }

  static LoginInfo _failedLoginInfo(String error) {
    final loginInfo = LoginInfo();
    loginInfo.success = false;
    loginInfo.error = error;
    return loginInfo;
  }
}
