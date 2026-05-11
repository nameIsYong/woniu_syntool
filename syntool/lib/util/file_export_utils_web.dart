import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

Future<void> exportStringToFile({
  required String content,
  required String fileName,
  String mimeType = 'text/plain',
}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchorElement = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchorElement);
    anchorElement.click();
    html.document.body?.children.remove(anchorElement);
    html.Url.revokeObjectUrl(url);

    debugPrint('文件导出成功: $fileName');
  } catch (e) {
    debugPrint('文件导出失败: $e');
    throw Exception('导出文件时出错: $e');
  }
}
