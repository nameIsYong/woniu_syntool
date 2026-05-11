class SyncDataResponse {
  final bool success;
  final String message;
  final int syncedCount;

  SyncDataResponse({
    required this.success,
    required this.message,
    required this.syncedCount,
  });
}