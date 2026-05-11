import 'package:flutter/material.dart';
import '../models/sync_task.dart';
import '../enums/task_status.dart';

abstract class TaskItemStateInterface {
  void resetRefreshState();
  void resetExportFailArchivesState(); // 添加重置导出失败档案状态的方法
}

class TaskItem extends StatefulWidget {
  final SyncTask task;
  final VoidCallback? onStartSync;
  final VoidCallback? onPauseSync;
  final VoidCallback? onResumeSync;
  final VoidCallback? onDeleteTask;
  final VoidCallback? onCheckDaziOnline;
  final VoidCallback? onRefreshDataSource;
  final Future<void> Function()? onExportFailArchives; // 修改为返回Future的回调

  const TaskItem({
    Key? key,
    required this.task,
    this.onStartSync,
    this.onPauseSync,
    this.onResumeSync,
    this.onDeleteTask,
    this.onCheckDaziOnline,
    this.onRefreshDataSource,
    this.onExportFailArchives,
  }) : super(key: key);

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> implements TaskItemStateInterface {
  final ScrollController _logScrollController = ScrollController();
  bool _refreshing = false; // 添加刷新状态
  bool _exportingFailArchives = false; // 添加导出失败档案的加载状态
  // 移除了组件内的_scheduledPauseTime，使用SyncTask模型中的属性

  @override
  void initState() {
    super.initState();
    widget.task.addListener(_onTaskChanged);
  }

  @override
  void didUpdateWidget(TaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task != widget.task) {
      oldWidget.task.removeListener(_onTaskChanged);
      widget.task.addListener(_onTaskChanged);
    }
  }

  @override
  void dispose() {
    widget.task.removeListener(_onTaskChanged);
    _logScrollController.dispose(); // 清理ScrollController
    super.dispose();
  }

  void _scrollToBottom() {
    if (_logScrollController.hasClients) {
      // 由于使用reverse: true，我们跳转到0位置来显示最新内容
      _logScrollController.jumpTo(0);
    }
  }

  void _onTaskChanged() {
    if (mounted) {
      setState(() {});
      // 数据更新后滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = _getStatusColor();
    String statusText = _getStatusText();

    return Card(
      margin: const EdgeInsets.all(8.0),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务头部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SelectableText(
                  '${widget.task.importDataResponse.loginInfo.institutionName}/${widget.task.importDataResponse.loginInfo.doctorName}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    height: 1.5,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 40),
                Wrap(
                  spacing: 5,
                  children: [
                    if (widget.task.status == TaskStatus.stopped ||
                        widget.task.status == TaskStatus.finished)
                      ElevatedButton(
                        onPressed: widget.task.totalDataCount > 0
                            ? widget.onStartSync
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text(
                          '开始同步',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    if (widget.task.status == TaskStatus.running)
                      ElevatedButton(
                        onPressed: widget.onPauseSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text('暂停', style: TextStyle(fontSize: 12)),
                      ),
                    if (widget.task.status == TaskStatus.paused)
                      ElevatedButton(
                        onPressed: widget.onResumeSync,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(60, 30),
                        ),
                        child: const Text('继续', style: TextStyle(fontSize: 12)),
                      ),

                    //查看搭子是否在线
                    ElevatedButton(
                      onPressed: () => _checkDaziOnlineStatus(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text(
                        '查看搭子是否在线',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    // 刷新数据源
                    ElevatedButton(
                      onPressed: _refreshing
                          ? null
                          : () => _refreshData(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: _refreshing
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              '重新拉取数据',
                              style: TextStyle(fontSize: 12),
                            ),
                    ),
                   
                    // 导出失败档案
                    ElevatedButton(
                      onPressed: _exportingFailArchives
                          ? null
                          : () => _exportFailArchives(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: _exportingFailArchives
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              '导出失败档案',
                              style: TextStyle(fontSize: 12),
                            ),
                    ),
                     //定时关闭
                    ElevatedButton(
                      onPressed: () => _timerCloseTask(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 101, 31, 31),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: Text(
                        widget.task.scheduledPauseTime != null 
                          ? '定时暂停: ${widget.task.scheduledPauseTime!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledPauseTime!.minute.toString().padLeft(2, '0')}'
                          : '定时关闭',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                     // 添加删除按钮
                    ElevatedButton(
                      onPressed: () => _confirmDelete(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('删除任务', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 任务详情信息
            Wrap(
              spacing: 16,
              children: [
                _buildInfoItem('模块类型', widget.task.moduleType.displayName),
                _buildInfoItem(
                  '数据总条数',
                  '${widget.task.totalDataCount.toString()}/(未同步:${widget.task.importDataResponse.notSynCount}条)',
                ),
                _buildInfoItem('当前处理', widget.task.currentIndex.toString()),
                _buildInfoItem('剩余条数', widget.task.remainingCount.toString()),
                _buildInfoItem(
                  '预计耗时',
                  '${widget.task.remainingTime <= 0 ? '<1' : widget.task.remainingTime}分钟',
                ),
                _buildInfoItem(
                  '筛选日期',
                  widget.task.importDataResponse.getFilterDateString(),
                ),
                _buildInfoItem(
                  '账号',
                  ' ${widget.task.importDataResponse.loginInfo.account}/${widget.task.importDataResponse.loginInfo.password}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 日志显示区域
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Scrollbar(
                child: SingleChildScrollView(
                  controller: _logScrollController,
                  reverse: true, // 反转列表，使新项目出现在底部
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                    child: SelectableText(
                      widget.task.logEntries.join('\n'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),

          SelectableText(
            value,
            style: TextStyle(fontSize: 16, color: Color(0xFF1976D2), height: 1.5),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.task.status) {
      case TaskStatus.stopped:
        return Colors.grey;
      case TaskStatus.running:
        return Colors.green;
      case TaskStatus.finished:
        return Colors.blue;
      case TaskStatus.paused:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    switch (widget.task.status) {
      case TaskStatus.stopped:
        return '已停止';
      case TaskStatus.running:
        return '进行中...';
      case TaskStatus.finished:
        return '已结束';
      case TaskStatus.paused:
        return '已暂停';
    }
  }

  // 确认删除任务
  void _confirmDelete(BuildContext context) {
    // 如果任务正在运行，需要先停止
    var runingMsg = '该任务正在运行中，删除后将自动停止，是否继续？';
    var otherMsg = '确认删除该任务？';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          widget.task.status == TaskStatus.running ? runingMsg : otherMsg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭确认对话框
              widget.onPauseSync!(); // 先停止任务
              widget.onDeleteTask!(); // 然后删除任务
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  //定时关闭
  void _timerCloseTask(BuildContext context) {
    TimeOfDay now = TimeOfDay.now();
    TimeOfDay maxTime = const TimeOfDay(hour: 23, minute: 59); // 最晚到23:59
    
    showTimePicker(
      context: context,
      initialTime: now,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
      initialEntryMode: TimePickerEntryMode.dial, // 使用拨号盘模式
    ).then((pickedTime) {
      if (pickedTime != null) {
        // 检查选择的时间是否在有效范围内（当前时间到23:59之间）
        DateTime nowDateTime = DateTime.now();
        DateTime selectedDateTime = DateTime(
          nowDateTime.year,
          nowDateTime.month,
          nowDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // 如果选择的时间早于当前时间，表示是明天的时间，不允许设置
        if (selectedDateTime.isBefore(nowDateTime)) {
          // 使用弹窗提示替代SnackBar
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('时间选择错误'),
              content: const Text('选择的时间不能早于当前时间'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
          return;
        }

        // 设置定时暂停时间到SyncTask模型
        setState(() {
          widget.task.scheduledPauseTime = selectedDateTime;
          widget.task.getScheduledPauseTimeString();
        });

        // 记录定时暂停设置到日志
        widget.task.addLogEntry('已设置【定时停止】时间: 今天 ${widget.task.scheduledPauseTime!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledPauseTime!.minute.toString().padLeft(2, '0')}时会自动停止');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已设置【定时停止】时间: 今天${widget.task.scheduledPauseTime!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledPauseTime!.minute.toString().padLeft(2, '0')}')),
        );
      }
    });
  }

  //导出失败档案
  void _exportFailArchives(BuildContext context) async {
    // 设置导出状态为true
    setState(() {
      _exportingFailArchives = true;
    });

    try {
      // 调用导出功能，并等待其完成
      await widget.onExportFailArchives!();
    } catch (error) {
      // 即使出现错误也重置状态
      print('导出失败档案时出现错误: $error');
    } finally {
      // 无论成功还是失败，都要重置状态
      if (mounted) {
        setState(() {
          _exportingFailArchives = false;
        });
      }
    }
  }

  // 执行操作并在完成后重置导出状态
  void _executeAndReset(VoidCallback callback) {
    // 执行传入的回调函数
    callback();
    
    // 由于onExportFailArchives执行的是异步操作，我们需要一种方式来监听完成状态
    // 因为无法直接知道外部回调何时完成，我们暂时采用稍后重置状态的方式
    // 更好的方式是在外部回调中通知本组件重置状态
  }

  //查看搭子是否在线
  void _checkDaziOnlineStatus(BuildContext context) {
    widget.onCheckDaziOnline!();
  }

  //刷新数据
  void _refreshData(BuildContext context) {
    // 设置刷新状态为true
    setState(() {
      _refreshing = true;
    });

    // 暂停当前任务
    if (widget.task.status == TaskStatus.running) {
      widget.onPauseSync!();
    }

    // 调用刷新数据源的回调，传递一个完成回调
    widget.onRefreshDataSource!();
  }

  // 供外部调用以重置刷新状态
  @override
  void resetRefreshState() {
    if (mounted) {
      setState(() {
        _refreshing = false;
        _exportingFailArchives = false;
      });
    }
  }
  
  // 新增方法，供外部调用以重置导出失败档案的状态
  void resetExportFailArchivesState() {
    if (mounted) {
      setState(() {
        _exportingFailArchives = false;
      });
    }
  }

  // 检查是否需要定时暂停
  bool shouldPauseBySchedule() {
    // 直接使用SyncTask模型中的方法
    return widget.task.shouldPauseBySchedule();
  }

  // 获取定时暂停时间的字符串表示
  String getScheduledPauseTimeString() {
    if (widget.task.scheduledPauseTime == null) {
      return '';
    }
    return '定时暂停: ${widget.task.scheduledPauseTime!.hour.toString().padLeft(2, '0')}:${widget.task.scheduledPauseTime!.minute.toString().padLeft(2, '0')}';
  }
}
