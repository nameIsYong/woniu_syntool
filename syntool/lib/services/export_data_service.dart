import 'package:syn_tool/enums/module_type.dart';
import 'package:syn_tool/models/import_data_response.dart';
import 'package:syn_tool/models/login_info.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../util/map_extension.dart';
import 'package:intl/intl.dart';

part 'export_extension_dia.dart';
part 'export_extension_pypertension.dart';
part 'export_extension_archives.dart';
part 'export_extension_case_py.dart';
part 'export_extension_case_dia.dart';
part 'export_extension_hydiaCombine.dart';
part 'export_extension_tcm.dart';
part 'export_extension_physical.dart';
part 'export_extension_sign.dart';
part 'export_extension_screenging.dart';

class ExportDataService {
  // 导出数据接口 - 使用伪代码实现
  static Future<ImportDataResponse> httpExportServiceDatas({
    required LoginInfo loginInfo,
    required ModuleType moduleType,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    //
    //健康筛查
    if (moduleType == ModuleType.kScreening) {
      var result = await ExportScreeningExtension.httpExportScreeningDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      print("导入了数据---->${result.importedDataList.length}条");
      return result;

      //高血压随访
    } else if (moduleType == ModuleType.kHypertension) {
      var result =
          await ExportPypertensionExtension.httpExportPypertensionDatas(
            loginInfo: loginInfo,
            moduleType: moduleType,
            startDate: startDate ?? DateTime.parse("2026-01-01"),
            endDate: endDate ?? DateTime.now(),
          );
      result.loginInfo = loginInfo;
      print("导 高血压随访  ${result.importedDataList.length}");
      return result;

      ////糖尿病随访
    } else if (moduleType == ModuleType.kDiabetes) {
      var result = await ExportDiaExtension.httpExportDiaDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      return result;

      ///高糖合并随访
    } else if (moduleType == ModuleType.kHSM) {
      var result =
          await ExportHypDiaCombineExtension.httpExportHypDiaCombineDatas(
            loginInfo: loginInfo,
            moduleType: moduleType,
            startDate: startDate ?? DateTime.parse("2026-01-01"),
            endDate: endDate ?? DateTime.now(),
          );
      result.loginInfo = loginInfo;
      return result;

      ///档案
    } else if (moduleType == ModuleType.kArchives) {
      var result = await ExportArchivesExtension.httpExportArchivesDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      return result;

      //高血压专案
    } else if (moduleType == ModuleType.kCaseHyp) {
      var result = await ExportPyCaseExtension.httpExportPyCaseDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
      );
      result.loginInfo = loginInfo;
      return result;

      //糖尿病专案
    } else if (moduleType == ModuleType.kCaseDia) {
      var result = await ExportDiaCaseExtension.httpExportDiaCaseDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
      );
      result.loginInfo = loginInfo;
      return result;

      //中医辨识
    } else if (moduleType == ModuleType.kTCM) {
      var result = await ExportTCMExtension.httpExportTCMDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      return result;

      //体检
    } else if (moduleType == ModuleType.kPhysical) {
      var result = await ExportPhysicalExtension.httpExportPhysicalDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      return result;

      //签约
    } else if (moduleType == ModuleType.kSign) {
      var result = await ExportSignExtension.httpExportSignDatas(
        loginInfo: loginInfo,
        moduleType: moduleType,
        startDate: startDate ?? DateTime.parse("2026-01-01"),
        endDate: endDate ?? DateTime.now(),
      );
      result.loginInfo = loginInfo;
      return result;
    }

    var result = ImportDataResponse();
    result.loginInfo = loginInfo;
    result.moduleType = moduleType;
    return result;
  }
}
