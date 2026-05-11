class StringUtil {
  ///字符串是否为空
  static bool isEmpty(String? content) {
    if (content == null || content.isEmpty) {
      return true;
    }
    return false;
  }

  ///非空
  static bool isNotEmpty(String? content) {
    return !isEmpty(content);
  }

  ///隐藏电话号中间
  static String hiddenPhone(String? phone) {
    if (phone == null || phone.length < 11) {
      return "";
    }
    String bein = phone.substring(0, 3);
    String end = phone.substring(phone.length - 4);
    return bein + "****" + end;
  }

  ///隐藏身份证号中间
  static String hiddenIDCard(String? idCard) {
    if (idCard == null || idCard.length < 4) {
      return "";
    }
    String bein = idCard.substring(0, 2);
    String end = idCard.substring(idCard.length - 2);
    return bein + "**************" + end;
  }

  ///正则校验
  static bool regExp(String regExp, String string) {
    if (string.isEmpty) return false;
    return RegExp(regExp).hasMatch(string);
  }

  ///是否是正整数
  static bool isInt(String str) {
    if (StringUtil.isEmpty(str)) {
      return false;
    }
    bool isIntNum = StringUtil.regExp("^[1-9]\\d*\$", str);
    return isIntNum;
  }

  ///是否是double数字
  static bool isDouble(String str) {
    if (StringUtil.isEmpty(str)) {
      return false;
    }
    bool isDouble =
        StringUtil.regExp("^[1-9]\\d*\\.\\d*|0\\.\\d*[1-9]\\d*\$", str);
    return isDouble;
  }

  ///是否是（整型 或 浮点型）
  static bool isNum(String? str) {
    if (StringUtil.isEmpty(str)) {
      return false;
    }
    bool isInt = StringUtil.isInt(str!);
    bool isDouble = StringUtil.isDouble(str);
    bool isNumber = isInt || isDouble;
    return isNumber;
  }

  ///字符串转double
  static double? toDouble(String? str) {
    if (StringUtil.isEmpty(str) || !StringUtil.isNum(str!)) {
      return null;
    }
    return double.parse(str);
  }

  ///字符串转int
  static int? toInt(String? str) {
    if (StringUtil.isEmpty(str) || !StringUtil.isNum(str!)) {
      return null;
    }
    return int.parse(str);
  }

  ///文本编码替换
  static String urlEncode(String string) {
    String value = string;
    value.replaceAll("+", "replace");
    value = value.replaceAll("+", "%2B");
    value = value.replaceAll("=", "%3D");
    value = value.replaceAll("/", "%2F");
    value = value.replaceAll(" ", "%20");
    return value;
  }
}
