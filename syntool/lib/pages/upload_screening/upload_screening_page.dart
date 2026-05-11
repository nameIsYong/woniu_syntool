import 'package:flutter/material.dart';

import 'controllers/upload_screening_controller.dart';
import 'models/upload_screening_models.dart';
import 'models/upload_screening_view_state.dart';
import 'widgets/upload_screening_widgets.dart';

class UploadScreeningPage extends StatefulWidget {
  const UploadScreeningPage({super.key});

  @override
  State<UploadScreeningPage> createState() => _UploadScreeningPageState();
}

class _UploadScreeningPageState extends State<UploadScreeningPage> {
  final UploadScreeningController _controller = UploadScreeningController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _headersController = TextEditingController();
  String? _loginErrorText;
  bool _isShowingBlockingAlert = false;
  bool _isShowingUploadContinuePrompt = false;
  int _lastHeaderResetVersion = 0;
  bool _isProgrammaticallyClearingHeaders = false;

  @override
  void dispose() {
    _controller.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    setState(() {
      _loginErrorText = null;
    });
    await _controller.login(
      _accountController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  void _fillPasswordWithLastSixDigits() {
    final account = _accountController.text.trim();

    if (account.isEmpty) {
      setState(() {
        _loginErrorText = '请先输入账号';
      });
      return;
    }

    if (account.length < 6) {
      setState(() {
        _loginErrorText = '账号长度不足6位，无法截取后6位';
      });
      return;
    }

    setState(() {
      _passwordController.text = account.substring(account.length - 6);
      _loginErrorText = null;
    });
  }

  Future<void> _pickDateRange(UploadScreeningViewState state) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: state.startDate,
        end: state.endDate,
      ),
      locale: const Locale('zh', 'CN'),
    );
    if (picked == null) {
      return;
    }
    await _controller.updateDateRange(picked.start, picked.end);
  }

  Future<bool> _confirmLeaveIfNeeded() async {
    if (!_controller.state.hasUnsavedContext) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认离开'),
          content: const Text(
            '当前页面存在已查询数据、待上传列表、失败名单或上传过程状态，离开后这些内存数据将丢失。是否继续返回？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认离开'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _confirmAndStartUpload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('上传前提醒'),
          content: const Text(
            '请确认当前操作环境为非 Wi‑Fi 网络。只有在非 Wi‑Fi 网络下才允许执行上传。\n\n如已确认，请点击“知道了”继续；否则请取消本次操作。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _controller.startUpload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmLeaveIfNeeded,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('健康筛查上传'),
        ),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final state = _controller.state;
            _syncHeaderInputIfNeeded(state);
            _tryShowBlockingAlert(state);
            _tryShowUploadContinuePrompt(state);
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLoginSection(state),
                    const SizedBox(height: 16),
                    _buildQuerySection(state),
                    const SizedBox(height: 16),
                    _buildCsvSection(state),
                    const SizedBox(height: 16),
                    _buildHeaderSection(state),
                    const SizedBox(height: 16),
                    UploadScreeningSectionCard(
                      title: '统计概览',
                      child: UploadScreeningSummaryGrid(
                        summary: state.querySummary,
                        pendingCount: state.pendingUploadItems.length,
                        skippedCount: state.skippedCsvMatches.length,
                        failureCount: state.failedUploads.length,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActionSection(state),
                    const SizedBox(height: 16),
                    UploadScreeningSectionCard(
                      title: '过程日志',
                      child: UploadScreeningLogPanel(logs: state.logs),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _syncHeaderInputIfNeeded(UploadScreeningViewState state) {
    if (state.headerResetVersion == _lastHeaderResetVersion) {
      return;
    }
    _lastHeaderResetVersion = state.headerResetVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _headersController.text.isEmpty) {
        return;
      }
      _isProgrammaticallyClearingHeaders = true;
      _headersController.clear();
      _isProgrammaticallyClearingHeaders = false;
    });
  }

  void _tryShowBlockingAlert(UploadScreeningViewState state) {
    final message = state.blockingAlertMessage;
    if (message == null || _isShowingBlockingAlert) {
      return;
    }

    _isShowingBlockingAlert = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isShowingBlockingAlert = false;
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('登录状态异常'),
            content: Text(message),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );
      _controller.clearBlockingAlertMessage();
      _isShowingBlockingAlert = false;
    });
  }

  void _tryShowUploadContinuePrompt(UploadScreeningViewState state) {
    final message = state.uploadContinuePromptMessage;
    if (message == null || _isShowingUploadContinuePrompt) {
      return;
    }

    _isShowingUploadContinuePrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _isShowingUploadContinuePrompt = false;
        return;
      }

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('继续执行确认'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('先暂停'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('继续并重填请求头'),
              ),
            ],
          );
        },
      );

      if (shouldContinue == true) {
        _controller.confirmUploadContinueAndRequireNewHeaders();
      } else {
        _controller.dismissUploadContinuePrompt();
      }
      _isShowingUploadContinuePrompt = false;
    });
  }

  Widget _buildLoginSection(UploadScreeningViewState state) {
    return UploadScreeningSectionCard(
      title: '后台登录',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _accountController,
                  enabled: !state.isLoggingIn,
                  decoration: const InputDecoration(
                    labelText: '账号',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _passwordController,
                  enabled: !state.isLoggingIn,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '密码',
                    border: OutlineInputBorder(),
                    suffixIcon: TextButton(
                      onPressed:
                          (state.isLoggingIn || state.isPreparing || state.isUploading)
                              ? null
                              : _fillPasswordWithLastSixDigits,
                      child: const Text('<==账号后6位'),
                    ),
                  ),
                  onSubmitted: (_) => _submitLogin(),
                ),
              ),
              FilledButton(
                onPressed: (state.isLoggingIn || state.isPreparing || state.isUploading)
                    ? null
                    : _submitLogin,
                child: state.isLoggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录并查询'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.loginMessage.isEmpty ? '当前未登录' : state.loginMessage,
            style: TextStyle(
              color: state.hasLogin ? Colors.green[700] : Colors.black87,
            ),
          ),
          if (_loginErrorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _loginErrorText!,
              style: TextStyle(
                color: Colors.red[700],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuerySection(UploadScreeningViewState state) {
    final rangeText =
        '${UploadScreeningFormatters.formatDate(state.startDate)} 至 ${UploadScreeningFormatters.formatDate(state.endDate)}';
    return UploadScreeningSectionCard(
      title: '筛查数据查询',
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: (state.isPreparing || state.isUploading || state.isQuerying)
                ? null
                : () => _pickDateRange(state),
            child: const Text('切换日期范围'),
          ),
          FilledButton.tonal(
            onPressed: state.hasLogin &&
                    !state.isQuerying &&
                    !state.isPreparing &&
                    !state.isUploading
                ? _controller.queryScreeningData
                : null,
            child: state.isQuerying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('重新查询'),
          ),
          OutlinedButton(
            onPressed: state.canPauseQuery ? _controller.pauseQuery : null,
            child: const Text('暂停查询'),
          ),
          OutlinedButton(
            onPressed: state.canResumeQuery ? _controller.resumeQuery : null,
            child: const Text('恢复查询'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前查询时间范围：$rangeText'),
          const SizedBox(height: 8),
          Text(
            state.queryStatusMessage.isEmpty ? '等待查询' : state.queryStatusMessage,
            style: TextStyle(
              color: state.isQueryPaused
                  ? Colors.red[700]
                  : (state.isQuerying ? Colors.orange[700] : Colors.black87),
            ),
          ),
          if (state.queryProgress.hasProgress) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(label: Text('查询状态 ${state.queryProgress.currentStatusLabel}')),
                Chip(
                  label: Text(
                    '查询页进度 ${state.queryProgress.currentPage}/${state.queryProgress.totalPages}',
                  ),
                ),
                Chip(label: Text('已拉取 ${state.queryProgress.loadedCount} 条')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCsvSection(UploadScreeningViewState state) {
    return UploadScreeningSectionCard(
      title: 'CSV 报表',
      trailing: FilledButton.tonal(
        onPressed: (state.isPreparing || state.isUploading) ? null : _controller.importCsv,
        child: const Text('选择 .csv 文件'),
      ),
      child: Text(
        state.csvRecords.isEmpty
            ? '尚未导入 CSV 报表'
            : 'CSV 已导入 ${state.csvRecords.length} 条，当前已按姓名/身份证前14位/性别/日期容差 5 天规则计算：待上传 ${state.pendingUploadItems.length} 条，CSV 排除 ${state.skippedCsvMatches.length} 条',
      ),
    );
  }

  Widget _buildHeaderSection(UploadScreeningViewState state) {
    return UploadScreeningSectionCard(
      title: '云平台请求头文本',
      trailing: FilledButton.tonal(
        onPressed: (state.isPreparing || (state.isUploading && !state.isUploadPaused))
            ? null
            : () => _controller.updateHeaderText(_headersController.text),
        child: const Text('解析请求头'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _headersController,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: '请粘贴浏览器复制的完整请求头文本',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (_isProgrammaticallyClearingHeaders) {
                return;
              }
              if (value.trim().isEmpty && state.parsedHeaders != null) {
                _controller.updateHeaderText(value);
              }
            },
          ),
          const SizedBox(height: 12),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  state.parsedHeaders == null
                      ? '尚未解析请求头'
                      : (state.parsedHeaders!.isValid
                          ? '请求头校验通过，关键字段完整'
                          : '缺少关键字段：${state.parsedHeaders!.missingRequiredKeys.join('、')}'),
                  style: TextStyle(
                    color: state.parsedHeaders?.isValid == true
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
                if (state.isUploading && state.isUploadPaused) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '若因累计处理达到 ${UploadScreeningController.uploadContinuePromptThreshold} 条及以上而暂停，继续前必须重新粘贴并解析最新的云平台请求头。',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(UploadScreeningViewState state) {
    final phaseText = _phaseLabel(state.currentPhase);
    return UploadScreeningSectionCard(
      title: '上传操作',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: state.canPrepare ? _controller.prepareUpload : null,
                child: state.isPreparing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('准备上传'),
              ),
              FilledButton.tonal(
                onPressed: state.canStartUpload ? _confirmAndStartUpload : null,
                child: state.isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('开始上传'),
              ),
              OutlinedButton(
                onPressed: state.canPauseUpload ? _controller.pauseUpload : null,
                child: const Text('暂停上传'),
              ),
              OutlinedButton(
                onPressed: state.canResumeUpload ? _controller.resumeUpload : null,
                child: const Text('恢复上传'),
              ),
              OutlinedButton(
                onPressed:
                    state.failedUploads.isNotEmpty ? _controller.exportFailureCsv : null,
                child: const Text('导出失败名单'),
              ),
              OutlinedButton(
                onPressed: (!state.isPreparing && !state.isUploading)
                    ? _controller.resetAll
                    : null,
                child: const Text('重置页面状态'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(label: Text('阶段：$phaseText')),
              Chip(label: Text('待上传 ${state.pendingUploadItems.length}')),
              Chip(label: Text('CSV 排除 ${state.skippedCsvMatches.length}')),
              Chip(label: Text('失败 ${state.failedUploads.length}')),
              Chip(label: Text('页内已成功 ${state.successfulUploadedRecordIds.length}')),
            ],
          ),
          if (state.progress.hasDaIdProgress || state.progress.hasUploadProgress) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (state.progress.hasDaIdProgress)
                  Chip(
                    label: Text(
                      'daId 进度 ${state.progress.daIdProcessed}/${state.progress.daIdTotal}',
                    ),
                  ),
                if (state.progress.hasUploadProgress)
                  Chip(
                    label: Text(
                      '上传进度 ${state.progress.uploadProcessed}/${state.progress.uploadTotal}',
                    ),
                  ),
                if (state.progress.hasUploadProgress)
                  Chip(
                    label: Text(
                      '上传成功 ${state.progress.uploadSucceeded}/${state.progress.uploadTotal}',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  state.phaseMessage.isEmpty ? '等待操作' : state.phaseMessage,
                  style: TextStyle(
                    color: state.failedUploads.isNotEmpty
                        ? Colors.red[700]
                        : Colors.black87,
                  ),
                ),
                if (state.lastOperationError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    state.lastOperationError,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: 12,
                    ),
                  ),
                ],
                if (state.currentPhase == UploadPhase.completed &&
                    state.pendingUploadItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '浏览器环境可能限制部分请求头透传；如果云平台接口出现鉴权或跨域异常，需要改为代理/中转方案。',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SelectableText(
                  '每次点击“开始上传”时，页面都会先弹出提醒框。只有在你确认“知道了”后，系统才继续执行上传流程。',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  '批量获取 daId 或批量上传过程中，累计处理数量达到 ${UploadScreeningController.uploadContinuePromptThreshold} 条及以上时，系统会自动暂停并清空当前云平台请求头。若你决定继续，必须重新输入并解析请求头后，才能点击“恢复上传”。',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(UploadPhase phase) {
    switch (phase) {
      case UploadPhase.idle:
        return '初始';
      case UploadPhase.ready:
        return '准备完成';
      case UploadPhase.resolvingDaId:
        return '获取 daId 中';
      case UploadPhase.uploading:
        return '上传中';
      case UploadPhase.paused:
        return '已暂停';
      case UploadPhase.completed:
        return '上传结束';
    }
  }
}
