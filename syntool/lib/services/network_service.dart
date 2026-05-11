import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:syn_tool/models/http_model.dart';
import 'package:syn_tool/models/login_info.dart';
import 'package:syn_tool/services/auth_service.dart';
import '../util/map_extension.dart';

class NetworkService {
  // 登录接口 - 复用公共认证服务
  static Future<LoginInfo?> login(String username, String password) async {
    return AuthService.login(
      username,
      password,
      userAuthAgent: 'os=5;client=1;ver=0.0.1;role=2;business=UCMS',
    );
  }

  // 登录详情接口 - 复用公共认证服务
  static Future<LoginInfo?> getLoginDetailInfo(
    String token,
    String userId,
  ) async {
    return AuthService.getLoginDetailInfo(token, userId);
  }

  //查询该机构是否有在线的搭子
  static Future<HttpModel> getDaziIsOnline(
    String token,
    String insId,
    int status,
  ) async {
    try {
      // 设置请求参数
      var params = {'insId': insId, 'page': 1, 'size': 70};

      // 设置请求头
      var headers = {
        "PP-User-Agent": "os=2;ver=1;ctype=2",
        'Content-Type': 'application/json',
        'token': token,
      };
      // 将参数转换为表单格式
      var formBody = params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
          )
          .join('&');
      var apiPath =
          'http://messagecenter.2woniu.cn:6087/center/device/device/list';
      print("请求地址（设备列表）---->$apiPath,n请求参数---->$formBody");

      var response = await http.get(
        Uri.parse('$apiPath?$formBody'),
        headers: headers,
      );
      // 解析响应
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      var httpModel = HttpModel();
      // 检查状态码
      if (jsonResponse['status'] == 0) {
        // 登录成功
        var dataList = jsonResponse.listVal('data');
        print("获取到列表:$dataList");
        int onlineCount = 0;
        for (var item in dataList) {
          int survivalStatus = item['survivalStatus'] as int;
          if (survivalStatus == 1) {
            onlineCount++;
          }
        }
        httpModel.success = true;
        httpModel.orgOnlineCount = onlineCount;
      } else {
        httpModel.success = false;
        httpModel.error = jsonResponse['message'] ?? '查询失败';
      }
      return httpModel;
    } catch (e) {
      var httpModel = HttpModel();
      httpModel.success = false;
      httpModel.error = '网络错误: $e';
      return httpModel;
    }
  }
}
