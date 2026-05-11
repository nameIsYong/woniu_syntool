// 声明该文件是主库的一部分
part of 'export_data_service.dart';
//糖尿病专案模块
extension ExportDiaCaseExtension on ExportDataService {
  //导出糖尿病专案数据
  static Future<ImportDataResponse> httpExportDiaCaseDatas({
    required LoginInfo loginInfo,
    required ModuleType moduleType
  }) async {
    var result = ImportDataResponse();
    result.moduleType = moduleType;

    result = await httpExportNotSynDiaCaseDatas(
      pageIndex: 1,
      token: loginInfo.token,
      resultModel: result,
      areaCode: loginInfo.areaCode,
    );

    return result;
  }

  //导出未同步的糖尿病专案数据
  static Future<ImportDataResponse> httpExportNotSynDiaCaseDatas({
    required int pageIndex,
    required String token,
    required ImportDataResponse resultModel,
    required String areaCode,
  }) async {
    try {
      // 设置请求参数
      var params = {
        'areaCode': areaCode,
        'page': pageIndex,
        'size': 1000,
        'status': 0,
        'rhrStatus': 0,
        'syncStatus': '未同步',
        'type': 2, //糖尿病专案
      };

      // 设置请求头
      var headers = {
        "PP-User-Agent": "os=2;ver=1;ctype=2",
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'token': token,
      };

      // 将参数转换为表单格式
      var formBody = params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
          )
          .join('&');
      var apiPath = 'http://bmg.2woniu.cn/bmanage/publichealth/chronic/list';
      print("请求地址（未同步的糖尿病专案数据）---->$apiPath,n请求参数---->$formBody");
      // 发送POST请求 - 使用表单格式提交数据
      var response = await http.post(
        Uri.parse(apiPath),
        headers: headers,
        body: formBody,
      );

      // 解析响应
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      // 检查状态码
      if (jsonResponse['status'] == 0) {
        // 登录成功
        var data = jsonResponse.mapVal('data');
        print("\n获取数据----->$data");
        var total = data.intVal("total");
        var pageSize = data.intVal("pageSize");
        var pageNo = data.intVal("pageNo");
        //是否有下一页
        var isHasNextPage = total > (pageSize * pageNo);
        var results = data.listVal("results");
        int index = resultModel.importedDataList.length;
        for (var item in results) {
          var itemDic = item as Map<String, dynamic>;
          var userData = UserData();
          userData.index = index;
          userData.isUnsynced = 1;
          userData.dataId = itemDic.strVal("illId");
          userData.rhrId = itemDic.strVal("residentHealthRecordId");
          userData.name = itemDic.strVal("name");
          userData.idCard = itemDic.strVal("idCard");
          userData.moduleType = ModuleType.kCaseDia;
          resultModel.importedDataList.add(userData);
          index++;
        }
        if (isHasNextPage) {
          // 获取下一页数据
          return await httpExportNotSynDiaCaseDatas(
            pageIndex: pageIndex + 1,
            token: token,
            resultModel: resultModel,
            areaCode: areaCode,
          );
        } else {
          //查询同步失败的
          return await httpExportFailSynDiaCaseDatas(
            pageIndex: 1,
            token: token,
            resultModel: resultModel,
            areaCode: areaCode,
          );
        }
      } else {
        resultModel.errorMessage = jsonResponse['message'] ?? '导出失败';
        return resultModel;
      }
    } catch (e) {
      resultModel.errorMessage = '网络错误: $e';
      return resultModel;
    }
  }

  //导出高血压专案同步失败的数据
  static Future<ImportDataResponse> httpExportFailSynDiaCaseDatas({
    required int pageIndex,
    required String token,
    required ImportDataResponse resultModel,
    required String areaCode,
  }) async {
    try {
      // 设置请求参数
      var params = {
        'areaCode': areaCode,
        'page': pageIndex,
        'size': 1000,
        'status': 0,
        'rhrStatus': 0,
        'syncStatus': '同步失败',
        'type': 2,
      };

      // 设置请求头
      var headers = {
        "PP-User-Agent": "os=2;ver=1;ctype=2",
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        'token': token,
      };

      // 将参数转换为表单格式
      var formBody = params.entries
          .map(
            (e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}',
          )
          .join('&');
      var apiPath = 'http://bmg.2woniu.cn/bmanage/publichealth/chronic/list';
      print("请求地址（同步失败的糖尿病专案数据）---->$apiPath,n请求参数---->$formBody");
      // 发送POST请求 - 使用表单格式提交数据
      var response = await http.post(
        Uri.parse(apiPath),
        headers: headers,
        body: formBody,
      );

      // 解析响应
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      // 检查状态码
      if (jsonResponse['status'] == 0) {
        // 登录成功
        var data = jsonResponse.mapVal('data');
        print("\n获取数据----->$data");
        var total = data.intVal("total");
        var pageSize = data.intVal("pageSize");
        var pageNo = data.intVal("pageNo");
        //是否有下一页
        var isHasNextPage = total > (pageSize * pageNo);
        var results = data.listVal("results");
        int index = resultModel.importedDataList.length;
        for (var item in results) {
          var itemDic = item as Map<String, dynamic>;
          var userData = UserData();
          userData.index = index;
          userData.isUnsynced = 2;
          userData.dataId = itemDic.strVal("id");
          userData.rhrId = itemDic.strVal("residentHealthRecordId");
          userData.name = itemDic.strVal("name");
          userData.idCard = itemDic.strVal("idCard");
          userData.moduleType = ModuleType.kCaseDia;
          resultModel.importedDataList.add(userData);
          index++;
        }
        if (isHasNextPage) {
          // 获取下一页数据
          return await httpExportFailSynDiaCaseDatas(
            pageIndex: pageIndex + 1,
            token: token,
            resultModel: resultModel,
            areaCode: areaCode,
          );
        } else {
          return resultModel;
        }
      } else {
        resultModel.errorMessage = jsonResponse['message'] ?? '导出失败';
        return resultModel;
      }
    } catch (e) {
      resultModel.errorMessage = '网络错误: $e';
      return resultModel;
    }
  }
}
