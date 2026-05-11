import 'package:flutter/material.dart';
import 'dart:math';

///颜色工具类
class ColorUtil {
  /// 使用方式"#aabbcc"  或者 “aabbcc”
  static Color hex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  ///随机色
  static Color randomColor({int r = 255, int g = 255, int b = 255, a = 255}) {
    if (r == 0 || g == 0 || b == 0) return Colors.black;
    if (a == 0) return Colors.white;
    return Color.fromARGB(
      a,
      r != 255 ? r : Random.secure().nextInt(r),
      g != 255 ? g : Random.secure().nextInt(g),
      b != 255 ? b : Random.secure().nextInt(b),
    );
  }

  static Color animationColor(Color begin, Color end, double max, double cur) {
    return Color.lerp(end, begin, min(max/cur, 1.0)) ?? begin;
  }
}
