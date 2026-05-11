// 声明该文件是主库的一部分
part of 'export_data_service.dart';

//档案模块
extension ExportArchivesExtension on ExportDataService {
  // 导出档案数据
  static Future<ImportDataResponse> httpExportArchivesDatas({
    required LoginInfo loginInfo,
    required ModuleType moduleType,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    var result = ImportDataResponse();
    result.moduleType = moduleType;

    result = await ExportArchivesExtension.httpExportNotSynArchivesDatas(
      pageIndex: 1,
      token: loginInfo.token,
      startDate: startDate,
      endDate: endDate,
      resultModel: result,
    );

    return result;
  }

  // 导出未同步的档案数据
  static Future<ImportDataResponse> httpExportNotSynArchivesDatas({
    required int pageIndex,
    required String token,
    required DateTime startDate,
    required DateTime endDate,
    required ImportDataResponse resultModel,
  }) async {
    try {
      // 设置请求参数,createStart:建档时间
      var params = {
        'createStart': DateFormat('yyyy-MM-dd').format(startDate),
        'createEnd': DateFormat('yyyy-MM-dd').format(endDate),
        'syncStatus': 2,
        'unRegionCode': 0,
        'pageNo': pageIndex,
        'pageSize': 800,
        'phisStatus': 2,
        'status': 0,
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
      var apiPath =
          'http://bmg.2woniu.cn/bmanage/publichealth/healthrecord/list';
      print("请求地址（未同步的糖尿病随访）---->$apiPath,n请求参数---->$formBody");
      // 发送GET请求 - 参数通过URL传递
      var response = await http.get(
        Uri.parse('$apiPath?$formBody'),
        headers: headers,
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
          userData.isUnsynced = 0;
          userData.dataId = itemDic.strVal("id");
          userData.rhrId = itemDic.strVal("id");
          userData.name = itemDic.strVal("name");
          userData.idCard = itemDic.strVal("idCard");
          userData.moduleType = ModuleType.kArchives;
          resultModel.importedDataList.add(userData);
          index++;
        }
        if (isHasNextPage) {
          // 获取下一页数据
          return await ExportArchivesExtension.httpExportNotSynArchivesDatas(
            pageIndex: pageIndex + 1,
            token: token,
            startDate: startDate,
            endDate: endDate,
            resultModel: resultModel,
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

  //拉取档案
  static Future<String> httpGetBaseInfoBy({
    required String rhrId,
    required String token,
  }) async {
    try {
      var params = {'residentHealthRecordId': rhrId};
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
      var apiPath = 'https://wnjk.2woniu.cn/wnjkapp/resident/archives/baseInfo';
      // 发送GET请求 - 参数通过URL传递
      var response = await http.get(
        Uri.parse('$apiPath?$formBody'),
        headers: headers,
      );

      // 解析响应
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      // 检查状态码
      if (jsonResponse['status'] == 0) {
        // 登录成功
        var data = jsonResponse.mapVal('data');
        var name = data.mapVal("residentHealthRecord").strVal("name");
        print("\n获取数据----->$data");
        return "接口(archives/baseInfo)拉取成功->姓名:$name，rhrId:$rhrId";
      } else {
        String errorMessage = jsonResponse['message'] ?? '未知错误';
        return 'Fail：拉取档案失败 rhrId:$rhrId, $errorMessage';
      }
    } catch (e) {
      String errorMessage = '网络错误: $e';
      return 'Fail：拉取档案失败 rhrId:$rhrId, $errorMessage';
    }
  }
}
