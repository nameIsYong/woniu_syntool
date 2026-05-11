enum SmartMergePersonStatus {
  success,
  partialSuccess,
  failed,
  skipped,
}

class SmartMergeStrategy {
  final bool autoDeleteAuxiliary;

  const SmartMergeStrategy({
    required this.autoDeleteAuxiliary,
  });
}

class SmartMergeDeleteResult {
  final bool success;
  final String message;

  const SmartMergeDeleteResult({
    required this.success,
    required this.message,
  });
}

class SmartMergePersonResult {
  final String name;
  final String idCard;
  final int duplicateCount;
  final SmartMergePersonStatus status;
  final String step;
  final String message;
  final List<String> deleteFailureMessages;

  const SmartMergePersonResult({
    required this.name,
    required this.idCard,
    required this.duplicateCount,
    required this.status,
    required this.step,
    required this.message,
    this.deleteFailureMessages = const [],
  });
}

class SmartMergeProgress {
  final bool isRunning;
  final bool isCompleted;
  final int totalCount;
  final int processedCount;
  final String currentName;
  final String currentIdCard;
  final String currentStep;
  final SmartMergeStrategy? strategy;
  final List<SmartMergePersonResult> results;

  const SmartMergeProgress({
    required this.isRunning,
    required this.isCompleted,
    required this.totalCount,
    required this.processedCount,
    required this.currentName,
    required this.currentIdCard,
    required this.currentStep,
    required this.strategy,
    required this.results,
  });

  const SmartMergeProgress.idle()
      : isRunning = false,
        isCompleted = false,
        totalCount = 0,
        processedCount = 0,
        currentName = '',
        currentIdCard = '',
        currentStep = '',
        strategy = null,
        results = const [];

  SmartMergeProgress copyWith({
    bool? isRunning,
    bool? isCompleted,
    int? totalCount,
    int? processedCount,
    String? currentName,
    String? currentIdCard,
    String? currentStep,
    SmartMergeStrategy? strategy,
    List<SmartMergePersonResult>? results,
    bool clearStrategy = false,
  }) {
    return SmartMergeProgress(
      isRunning: isRunning ?? this.isRunning,
      isCompleted: isCompleted ?? this.isCompleted,
      totalCount: totalCount ?? this.totalCount,
      processedCount: processedCount ?? this.processedCount,
      currentName: currentName ?? this.currentName,
      currentIdCard: currentIdCard ?? this.currentIdCard,
      currentStep: currentStep ?? this.currentStep,
      strategy: clearStrategy ? null : (strategy ?? this.strategy),
      results: results ?? this.results,
    );
  }

  int get successCount =>
      results.where((item) => item.status == SmartMergePersonStatus.success).length;

  int get failureCount =>
      results.where((item) => item.status == SmartMergePersonStatus.failed).length;

  int get skippedCount =>
      results.where((item) => item.status == SmartMergePersonStatus.skipped).length;

  int get partialSuccessCount => results
      .where((item) => item.status == SmartMergePersonStatus.partialSuccess)
      .length;

  int get deleteFailureCount => results
      .fold<int>(0, (sum, item) => sum + item.deleteFailureMessages.length);
}
