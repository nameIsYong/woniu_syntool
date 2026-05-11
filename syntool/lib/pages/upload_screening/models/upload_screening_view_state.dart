import '../../../models/login_info.dart';
import 'upload_screening_models.dart';

class UploadScreeningViewState {
  UploadScreeningViewState({
    required this.startDate,
    required this.endDate,
    this.loginInfo,
    this.isLoggingIn = false,
    this.loginMessage = '',
    this.isQuerying = false,
    this.isQueryPaused = false,
    this.queryStatusMessage = '',
    this.queryProgress = const QueryProgressSnapshot(),
    this.querySummary = const ScreeningQuerySummary(),
    this.allRecords = const <UploadScreeningRecord>[],
    this.csvRecords = const <CsvUploadedRecord>[],
    this.parsedHeaders,
    this.pendingUploadItems = const <PreparedUploadItem>[],
    this.skippedCsvMatches = const <PreparedUploadItem>[],
    this.currentPhase = UploadPhase.idle,
    this.phaseMessage = '',
    this.progress = const UploadProgressSnapshot(),
    this.logs = const <DelayLog>[],
    this.failedUploads = const <UploadFailureRecord>[],
    this.successfulUploadedRecordIds = const <int>{},
    this.isPreparing = false,
    this.isUploading = false,
    this.isUploadPaused = false,
    this.lastOperationError = '',
    this.blockingAlertMessage,
    this.uploadContinuePromptMessage,
    this.headerResetVersion = 0,
  });

  final DateTime startDate;
  final DateTime endDate;
  final LoginInfo? loginInfo;
  final bool isLoggingIn;
  final String loginMessage;
  final bool isQuerying;
  final bool isQueryPaused;
  final String queryStatusMessage;
  final QueryProgressSnapshot queryProgress;
  final ScreeningQuerySummary querySummary;
  final List<UploadScreeningRecord> allRecords;
  final List<CsvUploadedRecord> csvRecords;
  final ParsedCloudHeaders? parsedHeaders;
  final List<PreparedUploadItem> pendingUploadItems;
  final List<PreparedUploadItem> skippedCsvMatches;
  final UploadPhase currentPhase;
  final String phaseMessage;
  final UploadProgressSnapshot progress;
  final List<DelayLog> logs;
  final List<UploadFailureRecord> failedUploads;
  final Set<int> successfulUploadedRecordIds;
  final bool isPreparing;
  final bool isUploading;
  final bool isUploadPaused;
  final String lastOperationError;
  final String? blockingAlertMessage;
  final String? uploadContinuePromptMessage;
  final int headerResetVersion;

  bool get hasLogin => loginInfo?.success == true && (loginInfo?.token.isNotEmpty ?? false);

  bool get hasQueryResult => allRecords.isNotEmpty;

  bool get hasCsv => csvRecords.isNotEmpty;

  bool get hasHeaders => parsedHeaders != null;

  bool get canPrepare =>
      hasLogin &&
      hasQueryResult &&
      hasCsv &&
      parsedHeaders != null &&
      parsedHeaders!.isValid &&
      !isPreparing &&
      !isUploading;

  bool get canStartUpload =>
      currentPhase == UploadPhase.ready &&
      pendingUploadItems.isNotEmpty &&
      !isUploading;

  bool get canPauseQuery => isQuerying && !isQueryPaused;
  bool get canResumeQuery => isQuerying && isQueryPaused;

  bool get canPauseUpload => isUploading && !isUploadPaused;
  bool get canResumeUpload =>
      isUploading && isUploadPaused && parsedHeaders != null && parsedHeaders!.isValid;

  bool get hasUnsavedContext =>
      allRecords.isNotEmpty ||
      pendingUploadItems.isNotEmpty ||
      failedUploads.isNotEmpty ||
      isUploading;

  UploadScreeningViewState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    LoginInfo? loginInfo,
    bool clearLoginInfo = false,
    bool? isLoggingIn,
    String? loginMessage,
    bool? isQuerying,
    bool? isQueryPaused,
    String? queryStatusMessage,
    QueryProgressSnapshot? queryProgress,
    ScreeningQuerySummary? querySummary,
    List<UploadScreeningRecord>? allRecords,
    List<CsvUploadedRecord>? csvRecords,
    ParsedCloudHeaders? parsedHeaders,
    bool clearParsedHeaders = false,
    List<PreparedUploadItem>? pendingUploadItems,
    List<PreparedUploadItem>? skippedCsvMatches,
    UploadPhase? currentPhase,
    String? phaseMessage,
    UploadProgressSnapshot? progress,
    List<DelayLog>? logs,
    List<UploadFailureRecord>? failedUploads,
    Set<int>? successfulUploadedRecordIds,
    bool? isPreparing,
    bool? isUploading,
    bool? isUploadPaused,
    String? lastOperationError,
    String? blockingAlertMessage,
    bool clearBlockingAlertMessage = false,
    String? uploadContinuePromptMessage,
    bool clearUploadContinuePromptMessage = false,
    int? headerResetVersion,
  }) {
    return UploadScreeningViewState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      loginInfo: clearLoginInfo ? null : (loginInfo ?? this.loginInfo),
      isLoggingIn: isLoggingIn ?? this.isLoggingIn,
      loginMessage: loginMessage ?? this.loginMessage,
      isQuerying: isQuerying ?? this.isQuerying,
      isQueryPaused: isQueryPaused ?? this.isQueryPaused,
      queryStatusMessage: queryStatusMessage ?? this.queryStatusMessage,
      queryProgress: queryProgress ?? this.queryProgress,
      querySummary: querySummary ?? this.querySummary,
      allRecords: allRecords ?? this.allRecords,
      csvRecords: csvRecords ?? this.csvRecords,
      parsedHeaders: clearParsedHeaders ? null : (parsedHeaders ?? this.parsedHeaders),
      pendingUploadItems: pendingUploadItems ?? this.pendingUploadItems,
      skippedCsvMatches: skippedCsvMatches ?? this.skippedCsvMatches,
      currentPhase: currentPhase ?? this.currentPhase,
      phaseMessage: phaseMessage ?? this.phaseMessage,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      failedUploads: failedUploads ?? this.failedUploads,
      successfulUploadedRecordIds:
          successfulUploadedRecordIds ?? this.successfulUploadedRecordIds,
      isPreparing: isPreparing ?? this.isPreparing,
      isUploading: isUploading ?? this.isUploading,
      isUploadPaused: isUploadPaused ?? this.isUploadPaused,
      lastOperationError: lastOperationError ?? this.lastOperationError,
      blockingAlertMessage: clearBlockingAlertMessage
          ? null
          : (blockingAlertMessage ?? this.blockingAlertMessage),
      uploadContinuePromptMessage: clearUploadContinuePromptMessage
          ? null
          : (uploadContinuePromptMessage ?? this.uploadContinuePromptMessage),
      headerResetVersion: headerResetVersion ?? this.headerResetVersion,
    );
  }
}
