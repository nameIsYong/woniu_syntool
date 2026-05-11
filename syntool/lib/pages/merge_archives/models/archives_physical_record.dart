/// 档案体检服务类型。
enum ServiceRecordType {
  unknown(0),

  /// 健康体检
  healthyCheckUp(1),

  /// 健康教育
  healthEdu(101),

  /// 健康筛查
  healthScreening(102),

  /// 高血压
  hypertension(3),

  /// 糖尿病
  diabetes(4),

  /// 中医辨识
  tcmConstitution(5),

  /// 高糖合并
  highGlucoseCombination(6),

  /// 重精患者
  psychosis(7),

  /// COPD
  copd(8),

  /// 肺结核
  tuberculosis(9),

  /// 孕产妇
  pregnantwoman(10),

  /// 儿童
  children(20),

  /// 脑卒中
  cerebralStroke(-1);

  final int value;

  const ServiceRecordType(this.value);

  /// 根据接口返回的服务类型值映射到本地枚举。
  static ServiceRecordType fromValue(dynamic value) {
    final intValue = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (intValue == null) return ServiceRecordType.unknown;
    for (final item in ServiceRecordType.values) {
      if (item.value == intValue) {
        return item;
      }
    }
    return ServiceRecordType.unknown;
  }
}

/// 体检列表中的最近服务数据项。
class PhysicalRecordTip {
  /// 指标 ID
  final int? id;

  /// 指标名称
  final String name;

  /// 指标值
  final String value;

  const PhysicalRecordTip({
    required this.id,
    required this.name,
    required this.value,
  });

  factory PhysicalRecordTip.fromJson(Map<String, dynamic> json) {
    return PhysicalRecordTip(
      id: json['id'] as int?,
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}

/// 档案今年体检列表项。
class ArchivesPhysicalRecord {
  /// 体检记录 ID
  final int? nodeId;

  /// 服务类型，参考 [ServiceRecordType]
  final int? csvId;

  /// 最近服务数据摘要
  final List<PhysicalRecordTip> tips;

  /// 服务类型名称
  final String serverTitle;

  /// 操作人机构 ID
  final String institutionId;

  /// 操作人机构名称
  final String institutionName;

  /// 操作人 ID
  final String operatorId;

  /// 操作人姓名
  final String operatorName;

  /// 操作人头像
  final String operatorIcon;

  /// 完善状态
  final int? perfectState;

  /// 同步状态
  final int? syncStatus;

  /// 同步系统标识
  final int? syncSystem;

  /// 服务日期
  final String serverTime;

  /// 下次服务日期
  final String nextTime;

  /// 是否属于高糖合并
  final int? belongToHsm;

  /// 高糖合并节点 ID
  final int? hsmNodeId;

  /// 数据来源 ID
  final int? sjlyId;

  /// 第三方随访医生名称
  final String thirdSfysName;

  /// 第三方机构名称
  final String thirdOrgName;

  const ArchivesPhysicalRecord({
    required this.nodeId,
    required this.csvId,
    required this.tips,
    required this.serverTitle,
    required this.institutionId,
    required this.institutionName,
    required this.operatorId,
    required this.operatorName,
    required this.operatorIcon,
    required this.perfectState,
    required this.syncStatus,
    required this.syncSystem,
    required this.serverTime,
    required this.nextTime,
    required this.belongToHsm,
    required this.hsmNodeId,
    required this.sjlyId,
    required this.thirdSfysName,
    required this.thirdOrgName,
  });

  /// 服务类型枚举值，便于后续业务侧直接判断类型。
  ServiceRecordType get serviceRecordType => ServiceRecordType.fromValue(csvId);

  /// 从体检列表接口响应中解析单条记录。
  factory ArchivesPhysicalRecord.fromJson(Map<String, dynamic> json) {
    final tips = json['tips'] as List<dynamic>? ?? const [];

    return ArchivesPhysicalRecord(
      nodeId: _intVal(json['nodeId']),
      csvId: _intVal(json['csvId']),
      tips: tips
          .whereType<Map>()
          .map((item) => PhysicalRecordTip.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      serverTitle: json['serverTitle']?.toString() ?? '',
      institutionId: json['institutionId']?.toString() ?? '',
      institutionName: json['institutionName']?.toString() ?? '',
      operatorId: json['operatorId']?.toString() ?? '',
      operatorName: json['operatorName']?.toString() ?? '',
      operatorIcon: json['operatorIcon']?.toString() ?? '',
      perfectState: _intVal(json['perfectState']),
      syncStatus: _intVal(json['syncStatus']),
      syncSystem: _intVal(json['syncSystem']),
      serverTime: json['serverTime']?.toString() ?? '',
      nextTime: json['nextTime']?.toString() ?? '',
      belongToHsm: _intVal(json['belongToHsm']),
      hsmNodeId: _intVal(json['hsmNodeId']),
      sjlyId: _intVal(json['sjlyId']),
      thirdSfysName: json['thirdSfysName']?.toString() ?? '',
      thirdOrgName: json['thirdOrgName']?.toString() ?? '',
    );
  }
}

/// 安全解析 int，兼容接口返回字符串数字的场景。
int? _intVal(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
