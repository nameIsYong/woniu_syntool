import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

Future<void> exportStringToFile({
  required String content,
  required String fileName,
  String mimeType = 'text/plain',
}) async {
  try {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null || location.path.isEmpty) {
      return;
    }

    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
      name: fileName,
    );
    await file.saveTo(location.path);
    debugPrint('文件导出成功: ${location.path}');
  } catch (e) {
    debugPrint('文件导出失败: $e');
    throw Exception('导出文件时出错: $e');
  }
}
