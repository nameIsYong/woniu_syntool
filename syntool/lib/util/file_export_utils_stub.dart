Future<void> exportStringToFile({
  required String content,
  required String fileName,
  String mimeType = 'text/plain',
}) async {
  throw UnsupportedError('当前平台不支持文件导出');
}
