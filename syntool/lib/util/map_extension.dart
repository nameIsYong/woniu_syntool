import 'dart:convert' as convert;
import 'string_util.dart';

///扩展，方便从Map直接取值
extension MapExtension on Map {
  ///Map
  Map mapVal(String key) {
    Object? obj = this[key];
    if (obj is Map) return obj;
    return {};
  }

  ///List值
  List listVal(String key) {
    Object? obj = this[key];
    if (obj is List) return obj;
    return [];
  }

  ///int值
  int intVal(String key) {
    return intValBy(key, 0);
  }

  ///int 值 ，place，解析失败的值
  int intValBy(String key, int placeVal) {
    Object? obj = this[key];
    if (obj is int) return obj;
    if (obj is String) {
      if (StringUtil.isNum(obj)) {
        return int.parse(obj);
      } else {}
    }

    return placeVal;
  }

  ///double值
  double doubleVal(String key) {
    Object? obj = this[key];
    if (obj is double) return obj;
    if (obj is int) return double.parse("$obj");
    if (obj is String && StringUtil.isNum(obj)) return double.parse(obj);
    return 0;
  }

  ///String值
  String strVal(String key) {
    Object? obj = this[key];
    if (obj == null) return "";
    if (obj is int || obj is double) return "$obj";
    if (obj is String) return obj;
    return "$obj";
  }

  ///Map 转 jsonString
  String toJsonStr() {
    Object? obj = convert.jsonEncode(this);
    return obj is String ? obj : "";
  }
}


