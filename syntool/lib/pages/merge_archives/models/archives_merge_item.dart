import 'archives_enum_maps.dart';
import 'archives_model.dart';

/// 合并项类型
enum MergeItemType {
  bothEmpty,      // 两边都不存在
  mainOnly,       // 仅主档案存在
  auxiliaryOnly,  // 仅辅档案存在
  equal,          // 两边相等
  conflict,       // 两边冲突
}

/// 合并项决策状态
enum MergeDecision {
  none,           // 未决策
  keepMain,       // 保留主档案
  keepAuxiliary,  // 保留辅档案
  autoKept,       // 自动保留
}

/// 筛选类型
enum FilterType {
  all,        // 全部
  conflict,   // 冲突
  auxiliary,  // 新增
  main,       // 主数据
}

/// 字段所属模块
enum FieldModule {
  familyInfo,               // 家庭信息
  personBaseInfo,           // 居民基本信息
  livingEnvironment,        // 生活环境
  personHistoryList,        // 既往史
  personFamilyHistoryList,  // 家族史
  personIllnessList,        // 遗传疾病史及残疾情况
}

/// 字段值类型
enum FieldValueType {
  string,
  int,
  object,  // 对象/数组整体
}

/// 合并项
class MergeItem {
  /// 唯一标识：模块名.字段路径
  final String uniqueKey;

  /// 所属模块
  final FieldModule module;

  /// 字段显示名称
  final String fieldName;

  /// 字段路径（如 "familyInfo.familyAddress"）
  final String fieldPath;

  /// 主档案值
  final dynamic mainValue;

  /// 辅档案值
  final dynamic auxiliaryValue;

  /// 决策状态
  MergeDecision decision;

  /// 新增项是否取消
  bool isAuxiliaryCancelled;

  /// 值类型
  final FieldValueType valueType;

  /// 枚举映射（如果有）
  final Map<dynamic, String>? enumMap;

  /// 是否为位运算枚举
  final bool isBitEnum;

  MergeItem({
    required this.uniqueKey,
    required this.module,
    required this.fieldName,
    required this.fieldPath,
    this.mainValue,
    this.auxiliaryValue,
    this.decision = MergeDecision.none,
    this.isAuxiliaryCancelled = false,
    this.valueType = FieldValueType.string,
    this.enumMap,
    this.isBitEnum = false,
  });

  MergeItemType? _forcedType;

  /// 强制设置类型（用于数组字段等需要自定义比较逻辑的场景）
  void forceType(MergeItemType type) {
    _forcedType = type;
  }

  /// 合并项类型
  MergeItemType get type {
    if (_forcedType != null) return _forcedType!;

    final mainValid = _isValueValid(mainValue);
    final auxValid = _isValueValid(auxiliaryValue);

    if (!mainValid && !auxValid) return MergeItemType.bothEmpty;
    if (mainValid && !auxValid) return MergeItemType.mainOnly;
    if (!mainValid && auxValid) return MergeItemType.auxiliaryOnly;
    if (_valuesEqual(mainValue, auxiliaryValue)) {
      return MergeItemType.equal;
    }
    return MergeItemType.conflict;
  }

  /// 是否需要用户决策
  bool get needUserDecision => type == MergeItemType.conflict;

  /// 是否已解决
  bool get isResolved {
    if (!needUserDecision) return true;
    return decision != MergeDecision.none;
  }

  /// 新增项是否处于"取消新增"状态
  bool get isAuxiliaryDisabled =>
      type == MergeItemType.auxiliaryOnly && isAuxiliaryCancelled;

  /// 获取最终值
  dynamic get finalValue {
    if (isAuxiliaryDisabled) return null;

    switch (decision) {
      case MergeDecision.keepMain:
      case MergeDecision.autoKept:
        return mainValue;
      case MergeDecision.keepAuxiliary:
        return auxiliaryValue;
      default:
        return null;
    }
  }

  /// 获取主档案显示值
  String get mainDisplayValue => _formatValue(mainValue);

  /// 获取辅档案显示值
  String get auxiliaryDisplayValue => _formatValue(auxiliaryValue);

  /// 获取最终显示值
  String get finalDisplayValue {
    final val = finalValue;
    return _formatValue(val);
  }

  /// 格式化值用于显示
  String _formatValue(dynamic value) {
    if (!_isValueValid(value)) return '';

    if (isBitEnum && enumMap != null) {
      final parsedValue = _tryParseInt(value);
      if (parsedValue != null) {
        final bitEnumMap = <int, String>{};
        enumMap!.forEach((key, label) {
          final parsedKey = _tryParseInt(key);
          if (parsedKey != null) {
            bitEnumMap[parsedKey] = label;
          }
        });
        if (parsedValue == 0 && bitEnumMap.containsKey(0)) {
          return bitEnumMap[0]!;
        }
        return bitEnumToString(parsedValue, bitEnumMap);
      }
    }

    if (enumMap != null) {
      final exactMatch = enumMap![value];
      if (exactMatch != null) return exactMatch;

      // 后端返回的枚举值有时是 String，有时是 int，这里统一做兼容。
      final parsedValue = _tryParseInt(value);
      if (parsedValue != null) {
        final intKeyMatch = enumMap![parsedValue];
        if (intKeyMatch != null) return intKeyMatch;

        final stringKeyMatch = enumMap![parsedValue.toString()];
        if (stringKeyMatch != null) return stringKeyMatch;
      }

      final stringMatch = enumMap![value.toString()];
      if (stringMatch != null) return stringMatch;

      return value.toString();
    }

    if (value is List) {
      if (value.isEmpty) return '';
      // 对象数组：生成摘要
      if (value.first is Map) {
        return _formatObjectArray(value.cast<Map<String, dynamic>>());
      }
      return value.map((e) => e.toString()).join(', ');
    }

    return value.toString();
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return int.tryParse(value.toString());
  }

  /// 格式化对象数组为摘要
  String _formatObjectArray(List<Map<String, dynamic>> list) {
    final buffer = StringBuffer();
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (i > 0) buffer.write('\n');
      buffer.write('• ');

      // 根据字段生成摘要
      if (item.containsKey('recordType')) {
        // PersonHistory
        final type = recordTypeMap[item['recordType'] as int?] ?? '';
        final name = item['name']?.toString() ?? '';
        final date = item['occurrenceDate']?.toString() ?? '';
        final occurrenceDateOther =
            item['occurrenceDateOther']?.toString() ?? '';
        final dateText = date.isNotEmpty
            ? date
            : occurrenceDateOther.isNotEmpty
            ? '日期：不详'
            : '';
        buffer.write('[$type] $name ${dateText.isNotEmpty ? dateText : ''}');
      } else if (item.containsKey('relationshipType')) {
        // PersonFamilyHistory
        final relation = relationshipTypeMap[item['relationshipType'] as int?] ?? '';
        final diseaseVal = item['disease'] as int?;
        final diseaseStr = diseaseVal != null ? bitEnumToString(diseaseVal, familyDiseaseMap) : '';
        final remark = item['remark']?.toString() ?? '';
        final containsOther =
            diseaseVal != null && (diseaseVal & 2048) == 2048;
        final remarkText =
            containsOther && remark.isNotEmpty ? ' 其他信息: $remark' : '';
        buffer.write(
          '[$relation] ${diseaseStr.isNotEmpty ? diseaseStr : '无'}$remarkText',
        );
      } else if (item.containsKey('diseaseKindId') || item.containsKey('diseaseId')) {
        // PersonIllness
        final diseaseId = item['diseaseId']?.toString() ?? '';
        final diseaseName = diseaseIdMap[diseaseId] ?? item['remark']?.toString() ?? '';
        final date = item['diagnosisDate']?.toString() ?? '';
        buffer.write('$diseaseName ${date.isNotEmpty ? '确诊: $date' : ''}');
      } else {
        buffer.write(item.toString());
      }
    }
    return buffer.toString();
  }

  /// 判断值是否有效（非空）
  static bool _isValueValid(dynamic value) {
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    if (value is Map && value.isEmpty) return false;
    return true;
  }

  /// 值相等判断
  static bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      // 对于数组，逐个元素toString比较（无序）
      final aSet = a.map((e) => e.toString()).toSet();
      final bSet = b.map((e) => e.toString()).toSet();
      return aSet.containsAll(bSet) && bSet.containsAll(aSet);
    }

    return a.toString() == b.toString();
  }
}
