# 体检合并页面需求文档

## 数据文件使用规范

### 1. 体检项名称映射

| 项目 | 说明 |
|------|------|
| **文件** | `assets/data/csv_name_mapping.json` |
| **格式** | JSON 数组：`[{"csvId": 300367, "name": "下次体检时间"}, ...]` |
| **用途** | 体检项显示名称的映射 |
| **使用代码** | `_getCsvName(parentId, csvId)` |

**示例：**
```json
[
  {"csvId": 200051, "name": "血常规"},
  {"csvId": 300367, "name": "下次体检时间"},
  {"csvId": 300702, "name": "体检时间"}
]
```

**回退策略：** 若 csvId 在映射表中不存在，则直接显示 csvId 的数字值。

---

### 2. 体检项枚举值映射

| 项目 | 说明 |
|------|------|
| **文件** | `assets/data/physical_item_enum_value.json` |
| **格式** | JSON 对象：`{"csvId": [{"label": "...", "value": "..."}, ...]}` |
| **用途** | 枚举类型体检项的值映射（如症状、健康评估等） |
| **使用代码** | `_getOptionDisplayName(value, parentId, csvId)` |

**示例：**
```json
{
  "300101": [
    {"label": "无", "value": "400201"},
    {"label": "头痛", "value": "400202"},
    {"label": "头晕", "value": "400203"}
  ],
  "300261": [
    {"label": "-", "value": "-"},
    {"label": "+-", "value": "+-"},
    {"label": "弱阳性", "value": "弱阳性"}
  ]
}
```

**注意：**
- `value` 字段可能是数字字符串（如 `"400201"`）或符号字符串（如 `"-"`、`"+"`）
- 查找时同时支持原始类型和字符串形式匹配

---

## 代码实现要点

### 映射表构建

```dart
// 1. 加载体检项名称映射（csvId -> name）
void _buildCsvNameMap(List<dynamic> items) {
  for (final item in items) {
    final csvId = item['csvId'] as int?;
    final name = item['name'] as String?;
    if (csvId != null && name != null) {
      _csvNameMap[csvId] = name;
    }
  }
}

// 2. 加载体检项枚举值映射（csvId -> {value -> label}）
void _buildCsvItemInfoMap(Map<String, dynamic> enumData) {
  enumData.forEach((csvIdStr, enumList) {
    final csvId = int.tryParse(csvIdStr);
    if (csvId == null || enumList is! List) return;
    
    final childsMap = <dynamic, String>{};
    for (final enumItem in enumList) {
      final label = enumItem['label'] as String?;
      final value = enumItem['value'];
      if (label != null && value != null) {
        final valueKey = value is int ? value : value.toString();
        childsMap[valueKey] = label;
      }
    }
    
    _csvItemInfoMap[csvIdStr] = _CsvItemInfo(
      csvName: '',
      childsMap: childsMap,
    );
  });
}
```

### 显示名称获取

```dart
// 获取体检项名称（如"下次体检时间"）
String _getCsvName(int parentId, int csvId) {
  if (_csvNameMap.containsKey(csvId)) {
    return _csvNameMap[csvId]!;
  }
  return csvId.toString();  // 回退：显示数字
}

// 获取选项值显示名称（如将 400201 转换为 "无"）
String _getOptionDisplayName(dynamic value, int parentId, int csvId) {
  final key = csvId.toString();
  final itemInfo = _csvItemInfoMap[key];
  
  if (itemInfo != null && itemInfo.isEnum) {
    // 先尝试原始类型匹配，再尝试字符串形式
    return itemInfo.childsMap[value] ?? 
           itemInfo.childsMap[value.toString()] ?? 
           value.toString();
  }
  
  return value.toString();  // 非枚举类型直接显示
}
```

---

## 文件依赖关系

```
lib/pages/merge_physical/physical_merge_page.dart
    ├── assets/data/csv_name_mapping.json (体检项名称)
    └── assets/data/physical_item_enum_value.json (枚举值映射)
```

---

## 更新记录

| 日期 | 变更内容 |
|------|----------|
| 2026-04-10 | 明确数据文件分离：csv_name_mapping.json 用于名称，physical_item_enum_value.json 用于枚举值 |
