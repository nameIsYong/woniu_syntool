
import 'package:syn_tool/enums/module_type.dart';
import 'package:syn_tool/models/login_info.dart';

class ImportDataResponse {
  String errorMessage = '';
  //导入的数据
  List<UserData> importedDataList = [];
  //开始日期
  DateTime? startDate;
  //结束日期
  DateTime? endDate;
  //登录的信息
  LoginInfo loginInfo = LoginInfo();
  //模块类型
  ModuleType moduleType = ModuleType.kUnknown;
//获取未同步的数据的个数
  get notSynCount => importedDataList.where((element) => element.isUnsynced <= 1).length;

///获取筛选日期
  String getFilterDateString() {
    String startDateString = startDate == null ? '' : startDate!.toString().substring(0, 10);
    String endDateString = endDate == null ? '' : endDate!.toString().substring(0, 10);
    return '$startDateString~$endDateString';
  }
}

class UserData {
  //序号
  int index = 0;
  //档案ID
  String rhrId = '';
  //姓名
  String name = '';
  //身份证号
  String idCard = '';
  //数据ID
  String dataId = '';
  //(1:未同步的数据，2：同步失败的数据)
  int isUnsynced = 0;
  //模块类型
  ModuleType moduleType = ModuleType.kUnknown;
}
