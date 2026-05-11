import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/auth_service.dart';
import '../../../util/file_export_utils.dart';
import '../models/upload_screening_models.dart';
import '../models/upload_screening_view_state.dart';
import '../services/upload_screening_cloud_service.dart';
import '../services/upload_screening_parser_service.dart';
import '../services/upload_screening_query_service.dart';

class UploadScreeningController extends ChangeNotifier {
  static const int uploadContinuePromptThreshold = 200;

  UploadScreeningController({
    UploadScreeningQueryService? queryService,
    UploadScreeningParserService? parserService,
    UploadScreeningCloudService? cloudService,
  })  : _queryService = queryService ?? UploadScreeningQueryService(),
        _parserService = parserService ?? UploadScreeningParserService(),
        _cloudService = cloudService ?? UploadScreeningCloudService(),
        _state = UploadScreeningViewState(
          startDate: DateTime(DateTime.now().year, 1, 1),
          endDate: DateTime.now().add(const Duration(days: 1)),
        );

  final UploadScreeningQueryService _queryService;
  final UploadScreeningParserService _parserService;
  final UploadScreeningCloudService _cloudService;
  bool _queryPauseRequested = false;
  bool _uploadPauseRequested = false;
  bool _waitingUploadContinueConfirm = false;
  int _uploadOperationCountSincePrompt = 0;
  Completer<void>? _queryResumeCompleter;
  Completer<void>? _uploadResumeCompleter;

  UploadScreeningViewState _state;
  UploadScreeningViewState get state => _state;

  Future<void> login(String account, String password) async {
    _updateState(
      _state.copyWith(
        isLoggingIn: true,
        loginMessage: '',
        lastOperationError: '',
        successfulUploadedRecordIds: <int>{},
      ),
    );

    try {
      final loginInfo = await AuthService.login(account, password);
      if (!loginInfo.success) {
        throw Exception(loginInfo.error);
      }
      _updateState(
        _state.copyWith(
          loginInfo: loginInfo,
          isLoggingIn: false,
          loginMessage: '登录成功：${loginInfo.institutionName}',
        ),
      );
      await queryScreeningData();
    } catch (error) {
      _updateState(
        _state.copyWith(
          isLoggingIn: false,
          loginMessage: '登录失败：${error.toString().replaceFirst('Exception: ', '')}',
          lastOperationError: error.toString(),
        ),
      );
    }
  }

  Future<void> updateDateRange(DateTime startDate, DateTime endDate) async {
    final nextState = _initialDataState(
      _state.copyWith(
        startDate: DateTime(startDate.year, startDate.month, startDate.day),
        endDate: DateTime(endDate.year, endDate.month, endDate.day),
      ),
    ).copyWith(
      queryStatusMessage:
          '日期范围已切换为 ${UploadScreeningFormatters.formatDate(startDate)} 至 ${UploadScreeningFormatters.formatDate(endDate)}，页面状态已重置',
    );
    _updateState(nextState);

    if (_state.hasLogin) {
      await queryScreeningData();
    }
  }

  Future<void> queryScreeningData() async {
    final loginInfo = _state.loginInfo;
    if (loginInfo == null || !loginInfo.success || loginInfo.token.isEmpty) {
      _updateState(
        _state.copyWith(
          queryStatusMessage: '请先登录后台管理系统',
          lastOperationError: '未登录',
        ),
      );
      return;
    }

    _updateState(
      _initialDataState(_state).copyWith(
        isQuerying: true,
        isQueryPaused: false,
        queryStatusMessage: '开始查询未同步健康筛查数据',
      ),
    );
    _queryPauseRequested = false;
    _queryResumeCompleter = null;

    try {
      final unsyncedRecords = await _queryAllPagesForStatus(
        token: loginInfo.token,
        syncStatus: ScreeningSyncStatus.unsynced,
      );

      _updateState(
        _state.copyWith(
          queryStatusMessage: '开始查询同步失败健康筛查数据',
        ),
      );

      final failedRecords = await _queryAllPagesForStatus(
        token: loginInfo.token,
        syncStatus: ScreeningSyncStatus.failed,
      );

      final merged = <UploadScreeningRecord>[
        ...unsyncedRecords,
        ...failedRecords,
      ];

      final deduplicatedMap = <int, UploadScreeningRecord>{};
      for (final record in merged) {
        deduplicatedMap.putIfAbsent(record.id, () => record);
      }

      _updateState(
        _state.copyWith(
          isQuerying: false,
          isQueryPaused: false,
          allRecords: deduplicatedMap.values.toList(),
          querySummary: ScreeningQuerySummary(
            unsyncedCount: unsyncedRecords.length,
            failedCount: failedRecords.length,
            mergedCount: merged.length,
            deduplicatedCount: deduplicatedMap.length,
          ),
          queryStatusMessage: '查询完成，等待导入 CSV 并准备上传',
        ),
      );
      _refreshPendingPreviewIfPossible();
    } catch (error) {
      _updateState(
        _state.copyWith(
          isQuerying: false,
          isQueryPaused: false,
          queryStatusMessage: '查询失败：${error.toString().replaceFirst('Exception: ', '')}',
          lastOperationError: error.toString(),
        ),
      );
    }
  }

  Future<void> importCsv() async {
    try {
      final csvContent = await _parserService.pickCsvContent();
      if (csvContent == null) {
        return;
      }
      final records = _parserService.parseCsv(csvContent);
      _updateState(
        _state.copyWith(
          csvRecords: records,
          phaseMessage: 'CSV 已导入，共 ${records.length} 条',
          currentPhase: UploadPhase.idle,
          pendingUploadItems: const <PreparedUploadItem>[],
          skippedCsvMatches: const <PreparedUploadItem>[],
          failedUploads: const <UploadFailureRecord>[],
          logs: const <DelayLog>[],
          progress: const UploadProgressSnapshot(),
          lastOperationError: '',
        ),
      );
      _refreshPendingPreviewIfPossible();
    } catch (error) {
      _updateState(
        _state.copyWith(
          phaseMessage: 'CSV 导入失败：${error.toString().replaceFirst('Exception: ', '')}',
          lastOperationError: error.toString(),
        ),
      );
    }
  }

  void updateHeaderText(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      _updateState(
        _state.copyWith(
          clearParsedHeaders: true,
          phaseMessage: _state.isUploading && _state.isUploadPaused
              ? '云平台请求头已清空，请重新输入后再恢复上传'
              : '云平台请求头文本为空',
        ),
      );
      return;
    }

    final parsed = _parserService.parseCloudHeaders(trimmed);
    _updateState(
      _state.copyWith(
        parsedHeaders: parsed,
        phaseMessage: parsed.isValid
            ? (_state.isUploading && _state.isUploadPaused
                ? '云平台请求头重新解析成功，请点击“恢复上传”继续'
                : '云平台请求头解析成功')
            : '云平台请求头缺少关键字段：${parsed.missingRequiredKeys.join('、')}',
        currentPhase: _state.isUploading && _state.isUploadPaused
            ? UploadPhase.paused
            : _state.currentPhase,
      ),
    );
  }

  Future<void> prepareUpload() async {
    if (!_state.hasLogin) {
      _updateState(_state.copyWith(phaseMessage: '请先登录后台管理系统'));
      return;
    }
    if (_state.allRecords.isEmpty) {
      _updateState(_state.copyWith(phaseMessage: '请先查询健康筛查数据'));
      return;
    }
    if (_state.csvRecords.isEmpty) {
      _updateState(_state.copyWith(phaseMessage: '请先导入已上传人员 CSV 报表'));
      return;
    }
    final parsedHeaders = _state.parsedHeaders;
    if (parsedHeaders == null) {
      _updateState(_state.copyWith(phaseMessage: '请先粘贴云平台请求头文本'));
      return;
    }
    if (!parsedHeaders.isValid) {
      _updateState(
        _state.copyWith(
          phaseMessage:
              '云平台请求头缺少关键字段：${parsedHeaders.missingRequiredKeys.join('、')}',
        ),
      );
      return;
    }

    _updateState(
      _state.copyWith(
        isPreparing: true,
        phaseMessage: '正在根据 CSV 规则生成待上传列表',
        failedUploads: const <UploadFailureRecord>[],
        logs: const <DelayLog>[],
        progress: const UploadProgressSnapshot(),
      ),
    );

    try {
      final preview = _buildPendingPreview();
      final pendingItems = preview.pendingItems;
      final matchedItems = preview.matchedItems;

      _updateState(
        _state.copyWith(
          isPreparing: false,
          pendingUploadItems: pendingItems,
          skippedCsvMatches: matchedItems,
          currentPhase: UploadPhase.ready,
          phaseMessage:
              '准备完成：待上传 ${pendingItems.length} 条，CSV 排除 ${matchedItems.length} 条，页内已成功上传 ${preview.sessionSucceededCount} 条',
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          isPreparing: false,
          phaseMessage: '准备上传失败：${error.toString().replaceFirst('Exception: ', '')}',
          lastOperationError: error.toString(),
        ),
      );
    }
  }

  Future<void> startUpload() async {
    if (!_state.canStartUpload) {
      _updateState(_state.copyWith(phaseMessage: '请先完成准备上传'));
      return;
    }

    final parsedHeaders = _state.parsedHeaders;
    if (parsedHeaders == null || !parsedHeaders.isValid) {
      _updateState(_state.copyWith(phaseMessage: '云平台请求头校验未通过'));
      return;
    }
    final loginInfo = _state.loginInfo;
    final areaCode = loginInfo?.areaCode.trim() ?? '';
    if (areaCode.isEmpty) {
      _updateState(
        _state.copyWith(
          phaseMessage: '当前登录用户未获取到区划 areaCode，无法请求云平台档案接口',
          lastOperationError: 'doctorInfo.areaCode 为空',
        ),
      );
      return;
    }

    _updateState(
      _state.copyWith(
        isUploading: true,
        isUploadPaused: false,
        currentPhase: UploadPhase.resolvingDaId,
        phaseMessage: '开始串行获取 daId',
        progress: UploadProgressSnapshot(
          daIdProcessed: 0,
          daIdTotal: _state.pendingUploadItems.length,
          uploadProcessed: 0,
          uploadTotal: _state.pendingUploadItems.length,
          uploadSucceeded: _state.successfulUploadedRecordIds.length,
        ),
        failedUploads: const <UploadFailureRecord>[],
        logs: const <DelayLog>[],
        lastOperationError: '',
      ),
    );
    _uploadPauseRequested = false;
    _waitingUploadContinueConfirm = false;
    _uploadOperationCountSincePrompt = 0;
    _uploadResumeCompleter = null;

    final failedUploads = <UploadFailureRecord>[];
    final successfulIds = Set<int>.from(_state.successfulUploadedRecordIds);
    final updatedItems = _state.pendingUploadItems
        .map(
          (item) => PreparedUploadItem(
            record: item.record,
            matchedCsvRecord: item.matchedCsvRecord,
          ),
        )
        .toList();

    try {
      for (var index = 0; index < updatedItems.length; index++) {
        final item = updatedItems[index];
        await _awaitIfUploadPaused();
        final delay = _cloudService.nextDelay();
        _appendLog(
          '第 ${index + 1} 条数据，获取 daId 前延迟 ${delay.inSeconds} 秒：${item.record.name} (${index + 1}/${updatedItems.length})',
        );
        await _delayWithPauseSupport(delay, forUpload: true);

        try {
          final activeHeaders = _currentValidHeaders();
          final result = await _cloudService.fetchDaId(
            idCard: item.record.idCard,
            areaCode: areaCode,
            headers: activeHeaders,
          );

          if (result.daId == null || result.daId!.isEmpty) {
            final reason = '第 ${index + 1} 条数据，获取 daId 失败：${result.message}';
            if (_isLoginExpiredMessage(reason)) {
              _stopUploadWithBlockingAlert(
                message: reason,
                updatedItems: updatedItems,
                failedUploads: failedUploads,
                successfulIds: successfulIds,
              );
              return;
            }
            failedUploads.add(
              UploadFailureRecord(
                item: item.copyForFailure(reason),
                reason: reason,
                occurredAt: DateTime.now(),
              ),
            );
            item.failureReason = reason;
            _appendLog(reason);
            _updateProgress(
              daIdProcessed: index + 1,
              daIdTotal: updatedItems.length,
            );
            await _pauseAfterThresholdIfNeeded(
              currentIndex: index + 1,
              total: updatedItems.length,
              phaseLabel: '获取 daId',
              continueActionLabel: '继续获取 daId',
            );
            continue;
          }

          item.daId = result.daId;
          item.daIdResolvedAt = DateTime.now();
          _appendLog(
            '第 ${index + 1} 条数据，获取 daId 成功：${item.record.name} -> ${result.daId}',
          );
          _updateProgress(
            daIdProcessed: index + 1,
            daIdTotal: updatedItems.length,
          );
          await _pauseAfterThresholdIfNeeded(
            currentIndex: index + 1,
            total: updatedItems.length,
            phaseLabel: '获取 daId',
            continueActionLabel: '继续获取 daId',
          );
        } catch (error) {
          final reason =
              '第 ${index + 1} 条数据，获取 daId 异常：${error.toString().replaceFirst('Exception: ', '')}';
          if (_isLoginExpiredMessage(reason)) {
            _stopUploadWithBlockingAlert(
              message: reason,
              updatedItems: updatedItems,
              failedUploads: failedUploads,
              successfulIds: successfulIds,
            );
            return;
          }
          failedUploads.add(
            UploadFailureRecord(
              item: item.copyForFailure(reason),
              reason: reason,
              occurredAt: DateTime.now(),
            ),
          );
          item.failureReason = reason;
          _appendLog(reason);
          _updateProgress(
            daIdProcessed: index + 1,
            daIdTotal: updatedItems.length,
          );
          await _pauseAfterThresholdIfNeeded(
            currentIndex: index + 1,
            total: updatedItems.length,
            phaseLabel: '获取 daId',
            continueActionLabel: '继续获取 daId',
          );
        }
      }

      // daId 阶段与正式上传阶段分别独立累计，避免跨阶段残留计数导致过早弹框。
      _uploadOperationCountSincePrompt = 0;
      _updateState(
        _state.copyWith(
          pendingUploadItems: updatedItems,
          failedUploads: failedUploads,
          currentPhase: UploadPhase.uploading,
          phaseMessage: '开始串行上传健康筛查数据',
        ),
      );

      for (var index = 0; index < updatedItems.length; index++) {
        final item = updatedItems[index];
        await _awaitIfUploadPaused();
        if ((item.daId ?? '').trim().isEmpty) {
          _updateProgress(
            uploadProcessed: index + 1,
            uploadTotal: updatedItems.length,
            uploadSucceeded: successfulIds.length,
          );
          continue;
        }

        final delay = _cloudService.nextDelay();
        _appendLog(
          '第 ${index + 1} 条数据，上传前延迟 ${delay.inSeconds} 秒：${item.record.name} (${index + 1}/${updatedItems.length})',
        );
        await _delayWithPauseSupport(delay, forUpload: true);

        try {
          final activeHeaders = _currentValidHeaders();
          final uploadResult = await _cloudService.uploadRecord(
            item: item,
            headers: activeHeaders,
          );

          item.uploadedAt = DateTime.now();
          if (uploadResult.success) {
            item.uploadSucceeded = true;
            successfulIds.add(item.record.id);
            _appendLog('第 ${index + 1} 条数据，上传成功：${item.record.name}');
          } else {
            item.uploadSucceeded = false;
            item.failureReason = uploadResult.message;
            if (_isLoginExpiredMessage(uploadResult.message)) {
              _stopUploadWithBlockingAlert(
                message: '第 ${index + 1} 条数据，上传失败：${uploadResult.message}',
                updatedItems: updatedItems,
                failedUploads: failedUploads,
                successfulIds: successfulIds,
              );
              return;
            }
            failedUploads.add(
              UploadFailureRecord(
                item: item.copyForFailure(uploadResult.message),
                reason: uploadResult.message,
                occurredAt: DateTime.now(),
              ),
            );
            _appendLog(
              '第 ${index + 1} 条数据，上传失败：${item.record.name}，原因：${uploadResult.message}',
            );
          }
          _updateProgress(
            uploadProcessed: index + 1,
            uploadTotal: updatedItems.length,
            uploadSucceeded: successfulIds.length,
          );
          await _pauseAfterThresholdIfNeeded(
            currentIndex: index + 1,
            total: updatedItems.length,
            phaseLabel: '上传',
            continueActionLabel: '继续上传',
          );
        } catch (error) {
          final reason =
              '第 ${index + 1} 条数据，上传异常：${error.toString().replaceFirst('Exception: ', '')}';
          if (_isLoginExpiredMessage(reason)) {
            _stopUploadWithBlockingAlert(
              message: reason,
              updatedItems: updatedItems,
              failedUploads: failedUploads,
              successfulIds: successfulIds,
            );
            return;
          }
          item.uploadedAt = DateTime.now();
          item.uploadSucceeded = false;
          item.failureReason = reason;
          failedUploads.add(
            UploadFailureRecord(
              item: item.copyForFailure(reason),
              reason: reason,
              occurredAt: DateTime.now(),
            ),
          );
          _appendLog('第 ${index + 1} 条数据，上传失败：${item.record.name}，原因：$reason');
          _updateProgress(
            uploadProcessed: index + 1,
            uploadTotal: updatedItems.length,
            uploadSucceeded: successfulIds.length,
          );
          await _pauseAfterThresholdIfNeeded(
            currentIndex: index + 1,
            total: updatedItems.length,
            phaseLabel: '上传',
            continueActionLabel: '继续上传',
          );
        }
      }

      _updateState(
        _state.copyWith(
          pendingUploadItems: updatedItems,
          failedUploads: failedUploads,
          successfulUploadedRecordIds: successfulIds,
          isUploading: false,
          isUploadPaused: false,
          currentPhase: UploadPhase.completed,
          phaseMessage:
              '上传结束：本次成功 ${updatedItems.where((item) => item.uploadSucceeded).length} 条，失败 ${failedUploads.length} 条，当前页面累计已成功 ${successfulIds.length} 条',
        ),
      );
    } catch (error) {
      _updateState(
        _state.copyWith(
          pendingUploadItems: updatedItems,
          failedUploads: failedUploads,
          isUploading: false,
          isUploadPaused: false,
          currentPhase: UploadPhase.completed,
          phaseMessage:
              '上传流程中断：${error.toString().replaceFirst('Exception: ', '')}',
          lastOperationError: error.toString(),
        ),
      );
    }
  }

  Future<void> exportFailureCsv() async {
    if (_state.failedUploads.isEmpty) {
      _updateState(_state.copyWith(phaseMessage: '本次没有失败记录可导出'));
      return;
    }

    final rows = <List<String>>[
      <String>['序号', '姓名', '身份证号', '筛查日期', '健康筛查ID', 'daId', '失败原因', '上传时间'],
    ];

    for (var index = 0; index < _state.failedUploads.length; index++) {
      final failure = _state.failedUploads[index];
      rows.add(
        <String>[
          '${index + 1}',
          failure.item.record.name,
          failure.item.record.idCard,
          failure.item.record.screeningDateText,
          '${failure.item.record.id}',
          failure.item.daId ?? '',
          failure.reason,
          UploadScreeningFormatters.formatDateTime(failure.occurredAt),
        ],
      );
    }

    final csv = rows.map(_toCsvLine).join('\n');
    await FileExportUtils.exportStringToFile(
      content: '\uFEFF$csv',
      fileName:
          '健康筛查上传失败名单_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
    _updateState(_state.copyWith(phaseMessage: '失败名单已导出'));
  }

  void resetAll() {
    _queryPauseRequested = false;
    _uploadPauseRequested = false;
    _waitingUploadContinueConfirm = false;
    _uploadOperationCountSincePrompt = 0;
    _queryResumeCompleter?.complete();
    _uploadResumeCompleter?.complete();
    _queryResumeCompleter = null;
    _uploadResumeCompleter = null;
    _updateState(_initialDataState(_state).copyWith(
      queryStatusMessage: '页面状态已重置',
      phaseMessage: '',
      logs: const <DelayLog>[],
      failedUploads: const <UploadFailureRecord>[],
      currentPhase: UploadPhase.idle,
      progress: const UploadProgressSnapshot(),
      successfulUploadedRecordIds: <int>{},
      clearUploadContinuePromptMessage: true,
      clearBlockingAlertMessage: true,
    ));
  }

  void pauseQuery() {
    if (!_state.canPauseQuery) {
      return;
    }
    _queryPauseRequested = true;
    _queryResumeCompleter ??= Completer<void>();
    _updateState(
      _state.copyWith(
        isQueryPaused: true,
        queryStatusMessage: '健康筛查查询已暂停',
      ),
    );
  }

  void resumeQuery() {
    if (!_state.canResumeQuery) {
      return;
    }
    _queryPauseRequested = false;
    _queryResumeCompleter?.complete();
    _queryResumeCompleter = null;
    _updateState(
      _state.copyWith(
        isQueryPaused: false,
        queryStatusMessage: '继续查询健康筛查数据',
      ),
    );
  }

  void pauseUpload() {
    if (!_state.canPauseUpload) {
      return;
    }
    _uploadPauseRequested = true;
    _uploadResumeCompleter ??= Completer<void>();
    _updateState(
      _state.copyWith(
        isUploadPaused: true,
        currentPhase: UploadPhase.paused,
        phaseMessage: '上传流程已暂停',
      ),
    );
  }

  void resumeUpload() {
    if (!_state.canResumeUpload) {
      return;
    }
    _uploadPauseRequested = false;
    _uploadResumeCompleter?.complete();
    _uploadResumeCompleter = null;
    _updateState(
      _state.copyWith(
        isUploadPaused: false,
        currentPhase: _state.progress.daIdProcessed < _state.progress.daIdTotal
            ? UploadPhase.resolvingDaId
            : UploadPhase.uploading,
        phaseMessage: '继续执行上传流程',
        clearUploadContinuePromptMessage: true,
      ),
    );
  }

  void clearBlockingAlertMessage() {
    if (_state.blockingAlertMessage == null) {
      return;
    }
    _updateState(_state.copyWith(clearBlockingAlertMessage: true));
  }

  void dismissUploadContinuePrompt() {
    if (_state.uploadContinuePromptMessage == null) {
      return;
    }
    _updateState(
      _state.copyWith(
        phaseMessage: '已暂停，等待你决定是否继续执行当前批量流程',
        clearUploadContinuePromptMessage: true,
      ),
    );
  }

  void confirmUploadContinueAndRequireNewHeaders() {
    if (_state.uploadContinuePromptMessage == null) {
      return;
    }
    _waitingUploadContinueConfirm = false;
    _uploadOperationCountSincePrompt = 0;
    _updateState(
      _state.copyWith(
        clearParsedHeaders: true,
        headerResetVersion: _state.headerResetVersion + 1,
        phaseMessage: '已清空云平台请求头，请重新输入并解析后，再点击“恢复上传”继续当前流程',
        clearUploadContinuePromptMessage: true,
      ),
    );
  }

  String exportDebugSnapshot() {
    final payload = <String, dynamic>{
      'dateRange': <String, dynamic>{
        'startDate': UploadScreeningFormatters.formatDate(_state.startDate),
        'endDate': UploadScreeningFormatters.formatDate(_state.endDate),
      },
      'querySummary': <String, dynamic>{
        'unsyncedCount': _state.querySummary.unsyncedCount,
        'failedCount': _state.querySummary.failedCount,
        'mergedCount': _state.querySummary.mergedCount,
        'deduplicatedCount': _state.querySummary.deduplicatedCount,
      },
      'pendingCount': _state.pendingUploadItems.length,
      'failedUploadCount': _state.failedUploads.length,
      'successfulUploadedRecordIds': _state.successfulUploadedRecordIds.toList(),
      'progress': <String, dynamic>{
        'daIdProcessed': _state.progress.daIdProcessed,
        'daIdTotal': _state.progress.daIdTotal,
        'uploadProcessed': _state.progress.uploadProcessed,
        'uploadTotal': _state.progress.uploadTotal,
        'uploadSucceeded': _state.progress.uploadSucceeded,
      },
      'phase': _state.currentPhase.name,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  UploadScreeningViewState _initialDataState(UploadScreeningViewState baseState) {
    return baseState.copyWith(
      isQuerying: false,
      isQueryPaused: false,
      queryProgress: const QueryProgressSnapshot(),
      querySummary: const ScreeningQuerySummary(),
      allRecords: const <UploadScreeningRecord>[],
      pendingUploadItems: const <PreparedUploadItem>[],
      skippedCsvMatches: const <PreparedUploadItem>[],
      failedUploads: const <UploadFailureRecord>[],
      logs: const <DelayLog>[],
      currentPhase: UploadPhase.idle,
      phaseMessage: '',
      progress: const UploadProgressSnapshot(),
      isPreparing: false,
      isUploading: false,
      isUploadPaused: false,
      lastOperationError: '',
      clearUploadContinuePromptMessage: true,
      clearBlockingAlertMessage: true,
    );
  }

  String _toCsvLine(List<String> columns) {
    return columns.map((cell) {
      final escaped = cell.replaceAll('"', '""');
      return '"$escaped"';
    }).join(',');
  }

  void _appendLog(String message) {
    final nextLogs = List<DelayLog>.from(_state.logs)
      ..insert(
        0,
        DelayLog(message: message, createdAt: DateTime.now()),
      );
    if (nextLogs.length > 20) {
      nextLogs.removeRange(20, nextLogs.length);
    }
    _updateState(_state.copyWith(logs: nextLogs));
  }

  void _updateState(UploadScreeningViewState newState) {
    _state = newState;
    notifyListeners();
  }

  void _refreshPendingPreviewIfPossible() {
    if (_state.allRecords.isEmpty || _state.csvRecords.isEmpty) {
      return;
    }

    final preview = _buildPendingPreview();
    _updateState(
      _state.copyWith(
        pendingUploadItems: preview.pendingItems,
        skippedCsvMatches: preview.matchedItems,
        phaseMessage:
            'CSV 已匹配完成：待上传 ${preview.pendingItems.length} 条，CSV 排除 ${preview.matchedItems.length} 条，页内已成功上传 ${preview.sessionSucceededCount} 条',
      ),
    );
  }

  _PendingPreviewResult _buildPendingPreview() {
    final matchedItems = <PreparedUploadItem>[];
    final pendingItems = <PreparedUploadItem>[];
    var sessionSucceededCount = 0;

    for (final record in _state.allRecords) {
      if (_state.successfulUploadedRecordIds.contains(record.id)) {
        sessionSucceededCount++;
        continue;
      }

      CsvUploadedRecord? matchedCsv;
      for (final csvRecord in _state.csvRecords) {
        if (_parserService.isCsvMatched(record: record, csvRecord: csvRecord)) {
          matchedCsv = csvRecord;
          break;
        }
      }

      final item = PreparedUploadItem(
        record: record,
        matchedCsvRecord: matchedCsv,
      );
      if (matchedCsv == null) {
        pendingItems.add(item);
      } else {
        matchedItems.add(item);
      }
    }

    return _PendingPreviewResult(
      pendingItems: pendingItems,
      matchedItems: matchedItems,
      sessionSucceededCount: sessionSucceededCount,
    );
  }

  void _updateProgress({
    int? daIdProcessed,
    int? daIdTotal,
    int? uploadProcessed,
    int? uploadTotal,
    int? uploadSucceeded,
  }) {
    _updateState(
      _state.copyWith(
        progress: UploadProgressSnapshot(
          daIdProcessed: daIdProcessed ?? _state.progress.daIdProcessed,
          daIdTotal: daIdTotal ?? _state.progress.daIdTotal,
          uploadProcessed: uploadProcessed ?? _state.progress.uploadProcessed,
          uploadTotal: uploadTotal ?? _state.progress.uploadTotal,
          uploadSucceeded: uploadSucceeded ?? _state.progress.uploadSucceeded,
        ),
      ),
    );
  }

  bool _isLoginExpiredMessage(String message) {
    const keywords = <String>['登录', '失效', '重新', '过期'];
    return keywords.any(message.contains);
  }

  ParsedCloudHeaders _currentValidHeaders() {
    final parsedHeaders = _state.parsedHeaders;
    if (parsedHeaders == null || !parsedHeaders.isValid) {
      throw Exception('云平台请求头校验未通过，请重新输入并解析后再继续');
    }
    return parsedHeaders;
  }

  void _stopUploadWithBlockingAlert({
    required String message,
    required List<PreparedUploadItem> updatedItems,
    required List<UploadFailureRecord> failedUploads,
    required Set<int> successfulIds,
  }) {
    _uploadPauseRequested = false;
    _waitingUploadContinueConfirm = false;
    _uploadResumeCompleter?.complete();
    _uploadResumeCompleter = null;
    _updateState(
      _state.copyWith(
        pendingUploadItems: updatedItems,
        failedUploads: failedUploads,
        successfulUploadedRecordIds: successfulIds,
        isUploading: false,
        isUploadPaused: false,
        currentPhase: UploadPhase.completed,
        phaseMessage: '检测到登录已过期，当前上传流程已终止',
        lastOperationError: message,
        blockingAlertMessage: message,
        clearUploadContinuePromptMessage: true,
      ),
    );
  }

  Future<bool> _pauseAfterThresholdIfNeeded({
    required int currentIndex,
    required int total,
    required String phaseLabel,
    required String continueActionLabel,
  }) async {
    if (!_registerUploadOperationAndMaybePause(
      currentIndex: currentIndex,
      total: total,
      phaseLabel: phaseLabel,
      continueActionLabel: continueActionLabel,
    )) {
      return false;
    }
    await _awaitIfUploadPaused();
    return true;
  }

  bool _registerUploadOperationAndMaybePause({
    required int currentIndex,
    required int total,
    required String phaseLabel,
    required String continueActionLabel,
  }) {
    _uploadOperationCountSincePrompt++;
    if (_uploadOperationCountSincePrompt < uploadContinuePromptThreshold) {
      return false;
    }

    _uploadPauseRequested = true;
    _waitingUploadContinueConfirm = true;
    _uploadResumeCompleter ??= Completer<void>();
    _updateState(
      _state.copyWith(
        isUploadPaused: true,
        currentPhase: UploadPhase.paused,
        clearParsedHeaders: true,
        headerResetVersion: _state.headerResetVersion + 1,
        phaseMessage:
            '已累计处理 ${uploadContinuePromptThreshold} 条及以上$phaseLabel数据，云平台请求头已清空，请确认是否继续',
        uploadContinuePromptMessage:
            '当前批量$phaseLabel流程已累计处理到第 $currentIndex/$total 条，已达到继续提醒阈值 ${uploadContinuePromptThreshold} 条。当前云平台请求头已被清空。若要$continueActionLabel，你必须重新输入并解析最新请求头。是否继续？',
      ),
    );
    return true;
  }

  Future<List<UploadScreeningRecord>> _queryAllPagesForStatus({
    required String token,
    required ScreeningSyncStatus syncStatus,
  }) async {
    const pageSize = 100;
    var page = 1;
    var totalPages = 1;
    int? firstPageTotal;
    final records = <UploadScreeningRecord>[];

    while (true) {
      await _awaitIfQueryPaused();

      final pageResult = await _queryService.queryPage(
        token: token,
        page: page,
        size: pageSize,
        startDate: _state.startDate,
        endDate: _state.endDate,
        syncStatus: syncStatus,
      );

      if (pageResult.pageNo == 1 && pageResult.total > 0) {
        firstPageTotal = pageResult.total;
        totalPages = (pageResult.total / pageResult.pageSize).ceil();
      } else if (firstPageTotal != null && pageResult.pageSize > 0) {
        totalPages = (firstPageTotal / pageResult.pageSize).ceil();
      } else if (pageResult.pageSize > 0) {
        totalPages = pageResult.records.length < pageResult.pageSize ? page : page + 1;
      }

      records.addAll(pageResult.records);
      _updateState(
        _state.copyWith(
          queryProgress: QueryProgressSnapshot(
            currentStatusLabel: syncStatus.label,
            currentPage: pageResult.pageNo,
            totalPages: totalPages,
            loadedCount: records.length,
          ),
          queryStatusMessage:
              '${syncStatus.label}查询进度：第 ${pageResult.pageNo}/$totalPages 页，已累计 ${records.length} 条',
        ),
      );

      final hasMore = firstPageTotal != null
          ? pageResult.pageNo < totalPages
          : (pageResult.pageSize > 0 && pageResult.records.length >= pageResult.pageSize);
      if (!hasMore) {
        break;
      }
      page = pageResult.pageNo + 1;
    }

    return records;
  }

  Future<void> _awaitIfQueryPaused() async {
    while (_queryPauseRequested) {
      _updateState(
        _state.copyWith(
          isQueryPaused: true,
          queryStatusMessage: '健康筛查查询已暂停，等待恢复',
        ),
      );
      _queryResumeCompleter ??= Completer<void>();
      await _queryResumeCompleter!.future;
      _updateState(
        _state.copyWith(
          isQueryPaused: false,
        ),
      );
    }
  }

  Future<void> _awaitIfUploadPaused() async {
    while (_uploadPauseRequested) {
      _updateState(
        _state.copyWith(
          isUploadPaused: true,
          currentPhase: UploadPhase.paused,
          phaseMessage: '上传流程已暂停，等待恢复',
        ),
      );
      _uploadResumeCompleter ??= Completer<void>();
      await _uploadResumeCompleter!.future;
      _updateState(
        _state.copyWith(
          isUploadPaused: false,
          currentPhase: _state.progress.daIdProcessed < _state.progress.daIdTotal
              ? UploadPhase.resolvingDaId
              : UploadPhase.uploading,
        ),
      );
    }
  }

  Future<void> _delayWithPauseSupport(
    Duration delay, {
    required bool forUpload,
  }) async {
    var remaining = delay;
    const tick = Duration(milliseconds: 200);
    while (remaining > Duration.zero) {
      if (forUpload) {
        await _awaitIfUploadPaused();
      } else {
        await _awaitIfQueryPaused();
      }
      final currentTick = remaining > tick ? tick : remaining;
      await Future.delayed(currentTick);
      remaining -= currentTick;
    }
  }
}

class _PendingPreviewResult {
  const _PendingPreviewResult({
    required this.pendingItems,
    required this.matchedItems,
    required this.sessionSucceededCount,
  });

  final List<PreparedUploadItem> pendingItems;
  final List<PreparedUploadItem> matchedItems;
  final int sessionSucceededCount;
}
