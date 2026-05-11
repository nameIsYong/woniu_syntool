import 'package:shared_preferences/shared_preferences.dart';

class LoginHistoryUtil {
  static const String _key = 'login_history';

  // 保存登录信息到历史记录
  static Future<void> saveLoginInfo(String username, String password, String desc) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    // 检查是否已存在相同的用户名，如果存在则移除
    history.removeWhere((item) => _getUsernameFromItem(item) == username);
    
    // 将新登录信息添加到列表开头
    String newItem = '$username|$password|$desc';
    history.insert(0, newItem);
    
    // 限制历史记录数量，最多保留20条
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }
    
    await prefs.setStringList(_key, history);
  }

  // 获取历史登录信息列表
  static Future<List<Map<String, String>>> getLoginHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    List<Map<String, String>> result = [];
    for (String item in history) {
      List<String> parts = item.split('|');
      if (parts.length >= 3) {
        result.add({
          'username': parts[0],
          'password': parts[1],
          'desc':parts[2],
        });
      }
    }
    
    return result;
  }

  // 清除历史记录
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, []);
  }

  // 从存储项中提取用户名
  static String _getUsernameFromItem(String item) {
    List<String> parts = item.split('|');
    return parts.isNotEmpty ? parts[0] : '';
  }
}