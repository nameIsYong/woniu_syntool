import 'package:flutter/material.dart';
import 'package:syn_tool/models/http_model.dart';
import 'package:syn_tool/models/import_data_response.dart';
import 'package:syn_tool/services/export_data_service.dart';
import 'package:syn_tool/services/network_service.dart';
import 'package:syn_tool/util/file_export_utils.dart';
import '../models/sync_task.dart';
import '../widgets/task_item.dart';
import '../widgets/import_settings_dialog.dart';
import '../managers/task_manager.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({Key? key}) : super(key: key);

  @override
  _TaskListPageState createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final TaskManager _taskManager = TaskManager();
  bool _isLoadingDaziStatus = false; // 添加加载状态
  final Map<int, GlobalKey> _taskItemKeys = {}; // 用于访问TaskItem的引用

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                // 刷新数据
                if (mounted) setState(() {});
              },
              child: ValueListenableBuilder(
                valueListenable: ValueNotifier(_taskManager.tasks.length),
                builder: (context, value, child) {
                  if (_taskManager.tasks.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Center(
                          child: Text(
                            '暂无任务，请点击右下角按钮添加任务',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    itemCount: _taskManager.tasks.length,
                    itemBuilder: (context, index) {
                      final task = _taskManager.tasks[index];

                      // 为每个任务创建一个唯一的GlobalKey
                      if (!_taskItemKeys.containsKey(task.id)) {
                        _taskItemKeys[task.id] = GlobalKey();
                      }

                      return TaskItem(
                        key: _taskItemKeys[task.id], // 为TaskItem设置唯一key
                        task: task,
                        onStartSync: () => _startSync(task.id),
                        onPauseSync: () => _pauseSync(task.id),
                        onResumeSync: () => _resumeSync(task.id),
                        onDeleteTask: () => _deleteTask(task.id), // 添加删除任务回调
                        onCheckDaziOnline: () =>
                            _checkDaziOnlineStatus(task), // 添加检查搭子是否在线回调
                        onRefreshDataSource: () =>
                            _refreshDataSource(task.id), // 添加刷新数据源回调
                        onExportFailArchives: () =>
                            _exportFailArchives(task), // 添加导出失败档案回调
                      );
                    },
                  );
                },
              ),
            ),
          ),
          _buildFloatingBackButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        tooltip: '添加任务',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      child: Material(
        color: Colors.white.withOpacity(0.92),
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: '返回上一页',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
    );
  }

  void _addTask() {
    // 直接显示导入设置对话框，不需要检查登录状态
    showDialog(
      context: context,
      builder: (context) => ImportSettingsDialog(
        onConfirm:
            (
              response,
              moduleType,
              startDate,
              endDate,
              username,
              password,
              waitSeconds,
              randomMode,
            ) {
              if (response.importedDataList.isEmpty == true) {
                _showMessage('提示', '没有待导入的数据');
                return;
              }

              // 创建新任务
              final newTask = SyncTask(
                id: _taskManager.tasks.length + 1,
                taskName: moduleType.value,
                moduleType: moduleType,
                totalDataCount: response.importedDataList.length,
                currentIndex: 0,
                remainingCount: response.importedDataList.length,
                importDataResponse: response,
                waitSeconds: waitSeconds, // 设置waitSeconds参数
                randomMode: randomMode
              );

              // 添加一些初始日志
              var log =
                  '${response.loginInfo.institutionName}/${response.loginInfo.doctorName}/成功导入${moduleType.displayName} ${response.importedDataList.length} 条数据(日期范围: ${startDate.toString().split(' ')[0]} 至 ${endDate.toString().split(' ')[0]})';
              newTask.addLogEntry(log);
              _taskManager.addTask(newTask);

              if (mounted) {
                setState(() {});
              }
            },
      ),
    );
  }

  void _startSync(int taskId) {
    _taskManager.startTask(taskId);
    if (mounted) setState(() {});
  }

  void _pauseSync(int taskId) {
    _taskManager.pauseTask(taskId);
    if (mounted) setState(() {});
  }

  void _resumeSync(int taskId) {
    _taskManager.resumeTask(taskId);
    if (mounted) setState(() {});
  }

  // 删除任务
  void _deleteTask(int taskId) {
    _taskManager.removeTask(taskId);
    _taskItemKeys.remove(taskId); // 同时移除key
    if (mounted) setState(() {});
  }

  //刷新数据源
  Future<void> _refreshDataSource(int taskId) async {
    await _taskManager.refreshDataSource(taskId);

    // 数据源刷新完成后，重置对应TaskItem的刷新状态
    if (_taskItemKeys.containsKey(taskId)) {
      final key = _taskItemKeys[taskId];
      if (key != null) {
        // 检查key的currentState是否为TaskItemStateInterface的实例
        final Object? state = key.currentState;
        if (state != null && state is TaskItemStateInterface) {
          state.resetRefreshState();
        }
      }
    }
  }

  //导出失败档案
  Future<void> _exportFailArchives(SyncTask task) async {
    ImportDataResponse result = await ExportDataService.httpExportServiceDatas(
      loginInfo: task.importDataResponse.loginInfo,
      moduleType: task.moduleType,
      startDate: task.importDataResponse.startDate,
      endDate: task.importDataResponse.endDate,
    );
    print("准备导出文件:${result.importedDataList.length}条");
    if (result.importedDataList.isNotEmpty) {
      //弹框提示用户，是否需要导出失败数据
      //让用户选择导出文件目录，
      //导出数据
      String demoContent = "";
      for (var item in result.importedDataList) {
        demoContent += '${item.rhrId},${item.name},${item.idCard},\n';
      }
      if (demoContent.endsWith(",")) {
        demoContent = demoContent.substring(0, demoContent.length - 1);
      }
      // 调用导出方法
      await FileExportUtils.exportStringToFile(
        content: demoContent,
        fileName: '同步失败_${task.moduleType.displayName}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
    }
  }

  //检查搭子是否在线
  Future<void> _checkDaziOnlineStatus(SyncTask task) async {
    // 设置加载状态
    setState(() {
      _isLoadingDaziStatus = true;
    });

    try {
      HttpModel result = await NetworkService.getDaziIsOnline(
        task.importDataResponse.loginInfo.token,
        task.importDataResponse.loginInfo.institutionId,
        1,
      );
      if (result.success == true) {
        _showMessage(
          '提示',
          result.orgOnlineCount > 0 ? '${result.orgOnlineCount}个搭子在线' : '搭子不在线',
        );
      } else {
        _showMessage('提示', '查询失败');
      }
    } catch (e) {
      _showMessage('提示', '查询失败: $e');
    } finally {
      // 结束加载状态
      setState(() {
        _isLoadingDaziStatus = false;
      });
    }
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: _isLoadingDaziStatus
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('确定'),
          ),
        ],
      ),
    );
  }
}
