import 'file_export_utils_stub.dart'
    if (dart.library.html) 'file_export_utils_web.dart'
    if (dart.library.io) 'file_export_utils_io.dart' as exporter;

class FileExportUtils {
  /// 按平台导出文本文件：
  /// Web 直接触发浏览器下载，桌面端弹出保存位置选择框。
  static Future<void> exportStringToFile({
    required String content,
    required String fileName,
    String mimeType = 'text/plain',
  }) {
    return exporter.exportStringToFile(
      content: content,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
