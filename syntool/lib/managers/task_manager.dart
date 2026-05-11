import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:syn_tool/enums/module_type.dart';
import 'package:syn_tool/models/import_data_response.dart';
import 'package:syn_tool/services/export_data_service.dart';
import '../models/sync_task.dart';
import '../enums/task_status.dart';

class TaskManager {
  static final TaskManager _instance = TaskManager._internal();
  factory TaskManager() => _instance;
  TaskManager._internal();

  final List<SyncTask> _tasks = <SyncTask>[];
  int _nextId = 1;

  List<SyncTask> get tasks => List<SyncTask>.from(_tasks);

  // 添加任务
  void addTask(SyncTask task) {
    try {
      task.id = _nextId++;
      _tasks.add(task);
    } catch (e) {
      print('Error adding task: $e');
      rethrow;
    }
  }

  // 删除任务
  void removeTask(int taskId) {
    _tasks.removeWhere((task) => task.id == taskId);
  }

  // 开始同步任务
  Future<void> startTask(int taskId, {int fromIndex = 0}) async {
    final task = _tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    for (int i = 0; i < _tasks.length; i++) {
      var tempTask = _tasks[i];
      //该机构在跑其他数据
      if (tempTask.id != task.id &&
          tempTask.status == TaskStatus.running &&
          tempTask.importDataResponse.loginInfo.institutionId ==
              task.importDataResponse.loginInfo.institutionId) {
        task.addLogEntry(
          '该机构正在同步【${tempTask.moduleType.displayName}】数据，不能同时同步【${task.moduleType.displayName}】数据，太频繁了，怕被封号。。。。。。。。。。',
        );
        return;
      }
    }

    // 如果没有token，尝试先登录获取
    if (task.importDataResponse.loginInfo.token.isEmpty) {
      task.addLogEntry('请先登录...');
    }

    task.status = TaskStatus.running;

    // 重置进度
    task.currentIndex = fromIndex;
    task.remainingCount = task.totalDataCount;

    for (
      int i = task.currentIndex;
      i < task.importDataResponse.importedDataList.length;
      i++
    ) {
      var dataItem = task.importDataResponse.importedDataList[i];
      if (task.status != TaskStatus.running) {
        // 如果任务被暂停，则退出循环
        task.addLogEntry(
          '任务已暂停或停止，退出同步循环,第【$i】条数据待执行 => ${dataItem.name}/${dataItem.idCard}没有执行',
        );
        break;
      }
      //如果同步的是档案，则需要再拉取档案一次
      if (task.moduleType == ModuleType.kArchives) {
        task.addLogEntry(
          '第【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
        );
        // 获取档案数据
        var messageInfo = await ExportArchivesExtension.httpGetBaseInfoBy(
          rhrId: dataItem.rhrId,
          token: task.importDataResponse.loginInfo.token,
        );
        task.addLogEntry('第【${dataItem.index}】条，拉取档案：$messageInfo');
        //等待3秒
        await Future.delayed(Duration(seconds: 3));
      }

      task.updateProgress(i + 1);
      //同步
      task.addLogEntry(
        '第【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
      );
      //**********同步数据
      if(task.moduleType == ModuleType.kSign){
        //同步签约数据
        await httSynSignData(task, dataItem);
      }else{
        //同步其他服务
          await httSynData(task, dataItem);
      }
      

      int waitSeconds =
          task.waitSeconds;

//随机等待
      if (task.randomMode) {
         waitSeconds =
          task.waitSeconds + (DateTime.now().millisecondsSinceEpoch % 15);
          task.addLogEntry('----->等待 $waitSeconds 秒...');
   
      }
        await Future.delayed(Duration(seconds: waitSeconds));
      
      // 检查是否满足定时暂停条件
        String tempScheduledpausetime = task.getScheduledPauseTimeString();
      if (task.shouldPauseBySchedule()) {
        task.addLogEntry('========>达到定时暂停时间($tempScheduledpausetime)，任务已暂停');
        pauseTask(taskId);
        break;
      }
    }

    // 检查是否完成所有数据同步
    if (task.currentIndex >= task.totalDataCount) {
      task.status = TaskStatus.finished;
      task.addLogEntry('SUCCESS====================同步完成，正在查询结果....稍等.....\n');
      //查询结果
      ImportDataResponse newResult =
          await ExportDataService.httpExportServiceDatas(
            loginInfo: task.importDataResponse.loginInfo,
            moduleType: task.moduleType,
            startDate: task.importDataResponse.startDate,
            endDate: task.importDataResponse.endDate,
          );
      task.addLogEntry(
        '查询结果：${task.importDataResponse.loginInfo.institutionName}/${task.moduleType.displayName} 总共处理了【${task.importDataResponse.importedDataList.length}】条，失败了【${newResult.importedDataList.length}】条\n\n',
      );

      
    } else {
      task.addLogEntry('同步被暂停');
    }
  }

  // 暂停任务
  void pauseTask(int taskId) {
    final task = _tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    if (task.status == TaskStatus.running) {
      task.status = TaskStatus.paused;
      task.addLogEntry('任务已暂停');
    }
  }

  // 继续任务
  void resumeTask(int taskId) {
    final task = _tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    if (task.status == TaskStatus.paused) {
      task.status = TaskStatus.running;
      UserData dataItem =
          task.importDataResponse.importedDataList[task.currentIndex];
      task.addLogEntry(
        '任务已继续，从第${task.currentIndex}条数据开始，执行=> ${dataItem.name}/${dataItem.idCard}',
      );
      // 重新启动任务同步
      startTask(taskId, fromIndex: task.currentIndex);
    }
  }

  // 重置任务
  void resetTask(int taskId) {
    final task = _tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    task.resetTask();
  }

  // 同步服务数据
  Future<void> httSynData(SyncTask task, UserData dataItem) async {
    try {
      ImportDataResponse importDataResponse = task.importDataResponse;
      var params = {
        'module': importDataResponse.moduleType.value,
        "userId": importDataResponse.loginInfo.doctorId,
        "insId": importDataResponse.loginInfo.institutionId,
        "dataId": dataItem.dataId,
        "optType": 1,
      };

      // 设置请求头
      var headers = {
        "PP-User-Agent": "os=2;ver=1;ctype=2",
        'Content-Type': 'application/json',
        'token': importDataResponse.loginInfo.token,
      };
      var apiPath = 'https://wnjk.2woniu.cn/wnjkapp/sync/sync/service';
      print("请求地址---->$apiPath,n请求参数---->$params");
      // 发送POST请求
      var response = await http.post(
        Uri.parse(apiPath),
        headers: headers,
        body: json.encode(params),
      );
      task.addLogEntry(
        '==>准备执行【第${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
      );
      task.addLogEntry('请求参数:(sync/sync/service)，$params');
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      task.addLogEntry('响应结果:$jsonResponse');
      // 检查状态码
      if (jsonResponse['status'] == 0) {
        task.addLogEntry(
          '完成第【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
        );
      } else {
        // 登录失败
        var errorMsg = jsonResponse['message'] ?? '同步失败';
        task.addLogEntry(
          '******Fail:同步失败数据第【${dataItem.index}】条, ${dataItem.name}，${dataItem.idCard}，$errorMsg',
        );
      }
    } catch (e) {
      task.addLogEntry(
        '***失败Fail:【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId} 失败: $e',
      );
    }
  }

  //刷新数据源
  Future<bool> refreshDataSource(int taskId) async {
    pauseTask(taskId);
    final task = _tasks.firstWhere(
      (task) => task.id == taskId,
      orElse: () => throw Exception('Task not found'),
    );
    if (task.importDataResponse.loginInfo.token.isEmpty) {
      task.addLogEntry('刷新数据源失败，登录信息为空');
      return false;
    }
    ImportDataResponse result = await ExportDataService.httpExportServiceDatas(
      loginInfo: task.importDataResponse.loginInfo,
      moduleType: task.moduleType,
      startDate: task.importDataResponse.startDate,
      endDate: task.importDataResponse.endDate,
    );
    if (result.errorMessage.isEmpty) {
      task.addLogEntry('刷新数据源成功，共刷新了${result.importedDataList.length}条数据');
      //更新数据源
      task.updateDataSouce(result);
      task.resetTask();
    } else {
      task.addLogEntry('刷新数据源失败，${result.errorMessage}');
    }
    return true;
  }

  ///同步签约
  Future<void> httSynSignData(SyncTask task, UserData dataItem) async {
    try {
      ImportDataResponse importDataResponse = task.importDataResponse;
      var params = {
        'module': importDataResponse.moduleType.value,
        "userId": importDataResponse.loginInfo.doctorId,
        "insId": importDataResponse.loginInfo.institutionId,
        "dataId": dataItem.dataId,
        "optType": 1,
      };

      // 设置请求头
      var headers = {
        "PP-User-Agent": "os=2;ver=1;ctype=2",
        'Content-Type': 'application/json',
        'token': importDataResponse.loginInfo.token,
      };
      var apiPath = '';
      print("请求地址---->$apiPath,n请求参数---->$params");
      // 发送POST请求
      var response = await http.post(
        Uri.parse(apiPath),
        headers: headers,
        body: json.encode(params),
      );
      task.addLogEntry(
        '==>准备执行【第${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
      );
      task.addLogEntry('请求参数:(sync/sync/service)，$params');
      var jsonResponse = json.decode(response.body) as Map<String, dynamic>;

      task.addLogEntry('响应结果:$jsonResponse');
      // 检查状态码
      if (jsonResponse['status'] == 0) {
        task.addLogEntry(
          '完成第【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId}',
        );
      } else {
        // 登录失败
        var errorMsg = jsonResponse['message'] ?? '同步失败';
        task.addLogEntry(
          '******Fail:同步失败数据第【${dataItem.index}】条, ${dataItem.name}，${dataItem.idCard}，$errorMsg',
        );
      }
    } catch (e) {
      task.addLogEntry(
        '***失败Fail:【${dataItem.index}】条，${task.moduleType.displayName},${dataItem.name}，${dataItem.idCard}，数据ID:${dataItem.dataId} 失败: $e',
      );
    }
  }
}
