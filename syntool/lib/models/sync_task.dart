import 'package:syn_tool/models/import_data_response.dart';

import '../enums/task_status.dart';
import '../enums/module_type.dart';
import 'package:flutter/foundation.dart';

class SyncTask extends ChangeNotifier {
  int id = 0;
  String taskName = "";
  TaskStatus status = TaskStatus.stopped;
  ModuleType moduleType = ModuleType.kUnknown;
  int totalDataCount = 0;
  int currentIndex = 0;
  int remainingCount = 0;
  List<String> logEntries = <String>[];
  ImportDataResponse importDataResponse;
  // 每条数据同步后的等待时间，单位秒
  int waitSeconds = 0;//10到25秒之间随机
  //预计耗时，单位分钟(基本时间的1.5倍左右)，因为是随机时间+ 基础时间waitSeconds
  int get remainingTime =>
      (totalDataCount - currentIndex) * (waitSeconds + waitSeconds ~/ 2) ~/ 60;
  
  // 添加定时暂停相关的属性
  DateTime? scheduledPauseTime;
  // 是否开启随机等待模式
  bool randomMode;

  SyncTask({
    required this.id,
    required this.taskName,
    this.status = TaskStatus.stopped,
    this.moduleType = ModuleType.kUnknown,
    this.totalDataCount = 0,
    this.currentIndex = 0,
    this.remainingCount = 0,
    this.waitSeconds = 10, // 设置默认值为10
    this.scheduledPauseTime,
this.randomMode = false,
    List<String>? logEntries,
    ImportDataResponse? importDataResponse,
  }) : logEntries = logEntries ?? <String>[],
       importDataResponse = importDataResponse ?? ImportDataResponse();

  //更新新数据源
  void updateDataSouce(ImportDataResponse importDataResponse) {
    currentIndex = 0;
    totalDataCount = importDataResponse.importedDataList.length;
    remainingCount = totalDataCount;
    this.importDataResponse.importedDataList = importDataResponse.importedDataList;
  }

  void addLogEntry(String log, {bool isClear = true}) {
    print(log);
    
    if (isClear&& logEntries.length > 1000) {
      // 只保留最新的700条记录
      logEntries = logEntries.sublist(logEntries.length - 700);
    }

    logEntries.add('${DateTime.now().toString()} - $log');
    notifyListeners(); // 通知UI刷新
  }

  void updateProgress(int index) {
    currentIndex = index;
    remainingCount = totalDataCount - currentIndex;
    notifyListeners(); // 通知UI刷新
  }

  void resetTask() {
    status = TaskStatus.stopped;
    currentIndex = 0;
    remainingCount = totalDataCount;
    logEntries.clear();
    // 重置定时暂停时间
    scheduledPauseTime = null;
    notifyListeners(); // 通知UI刷新
  }
  
  // 检查是否需要定时暂停
  bool shouldPauseBySchedule() {
    if (scheduledPauseTime == null) {
      return false;
    }

    DateTime now = DateTime.now();
    // 检查当前时间是否已经超过了设定的定时暂停时间
    if (now.isAfter(scheduledPauseTime!)) {
      // 重置定时时间，防止重复暂停
      scheduledPauseTime = null;
      return true;
    }

    return false;
  }
  
  // 获取定时暂停时间的字符串表示
  String getScheduledPauseTimeString() {
    if (scheduledPauseTime == null) {
      return '';
    }
    return '定时暂停: ${scheduledPauseTime!.hour.toString().padLeft(2, '0')}:${scheduledPauseTime!.minute.toString().padLeft(2, '0')}';
  }
}