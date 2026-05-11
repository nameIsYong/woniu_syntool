import '../models/archives_model.dart';

class ArchivesSaveService {
  const ArchivesSaveService();

  static const Set<String> _personBaseInfoOptionalEmptyFields = <String>{
    'birthPlace',
    'birthPlaceCode',
    'placeOrigin',
    'placeOriginCode',
  };

  /// 构建保存参数
  /// [baseModel] 以主档案为基础
  /// [mergeValues] 合并后的字段值 Map<fieldPath, value>
  /// [spkgId] 服务包ID
  Map<String, dynamic> buildSavePayload({
    required ArchivesModel baseModel,
    required Map<String, dynamic> mergeValues,
    required int spkgId,
  }) {
    // 基础对象字段直接替换
    final familyInfo = _buildFamilyInfo(baseModel.familyInfo, mergeValues);
    final personBaseInfo = _buildPersonBaseInfo(baseModel.personBaseInfo, mergeValues);
    final livingEnvironment = _buildLivingEnvironment(baseModel.livingEnvironment, mergeValues);

    // 数组字段
    final personHistoryList = mergeValues['personHistoryList'] as List<dynamic>?
        ?? baseModel.personHistoryList.map((e) => e.toJson()).toList();
    final personFamilyHistoryList = mergeValues['personFamilyHistoryList'] as List<dynamic>?
        ?? baseModel.personFamilyHistoryList.map((e) => e.toJson()).toList();
    final personIllnessList = mergeValues['personIllnessList'] as List<dynamic>?
        ?? baseModel.personIllnessList.map((e) => e.toJson()).toList();

    // personBaseExtendsInfo 不参与合并，保留原值
    final personBaseExtendsInfo = baseModel.personBaseExtendsInfo;

    return {
      'familyInfo': familyInfo,
      'personBaseInfo': personBaseInfo,
      'personIllnessList': personIllnessList,
      'personFamilyHistoryList': personFamilyHistoryList,
      'personBaseExtendsInfo': personBaseExtendsInfo,
      'spkgId': spkgId,
      'livingEnvironment': livingEnvironment,
      'personHistoryList': personHistoryList,
      'callback': 'archiveSave_APPinjection_callback',
      'dataSourceFrom': '云平台',
    };
  }

  Map<String, dynamic>? _buildFamilyInfo(
    FamilyBaseInfoModel? base,
    Map<String, dynamic> mergeValues,
  ) {
    return _buildObjectPayload(
      baseJson: base?.toJson(),
      mergeValues: mergeValues,
      prefix: 'familyInfo.',
    );
  }

  Map<String, dynamic>? _buildPersonBaseInfo(
    PersonBaseInfo? base,
    Map<String, dynamic> mergeValues,
  ) {
    final payload = _buildObjectPayload(
      baseJson: base?.toJson(),
      mergeValues: mergeValues,
      prefix: 'personBaseInfo.',
    );
    if (payload == null) return null;

    // 云平台会把空字符串当作“有值”处理，这几个字段为空时直接移除 key，
    // 避免触发错误的非空校验逻辑。
    for (final field in _personBaseInfoOptionalEmptyFields) {
      if (_isEmpty(payload[field])) {
        payload.remove(field);
      }
    }

    return payload;
  }

  Map<String, dynamic>? _buildLivingEnvironment(
    LivingEnvironment? base,
    Map<String, dynamic> mergeValues,
  ) {
    return _buildObjectPayload(
      baseJson: base?.toJson(),
      mergeValues: mergeValues,
      prefix: 'livingEnvironment.',
    );
  }

  Map<String, dynamic>? _buildObjectPayload({
    required Map<String, dynamic>? baseJson,
    required Map<String, dynamic> mergeValues,
    required String prefix,
  }) {
    final json = Map<String, dynamic>.from(baseJson ?? <String, dynamic>{});
    var hasField = json.isNotEmpty;

    mergeValues.forEach((key, value) {
      if (!key.startsWith(prefix)) return;
      final field = key.substring(prefix.length);
      json[field] = value;
      hasField = true;
    });

    return hasField ? json : null;
  }

  /// 补全 personBaseExtendsInfo 默认值
  /// 参考原 Swift getDefault 逻辑
  Map<String, dynamic> complementPersonBaseExtendsInfo({
    required Map<String, dynamic>? baseExtendsInfo,
    required Map<String, dynamic>? mergedFamilyInfo,
    required ThirdAccountInfo doctor,
  }) {
    final result = Map<String, dynamic>.from(baseExtendsInfo ?? {});
    final family = mergedFamilyInfo ?? const <String, dynamic>{};

    // 建档机构
    if (_isEmpty(result['thirdCorg']) || _isEmpty(result['thirdJdJgId'])) {
      result['thirdCorg'] = doctor.thirdOrgId;
      result['thirdCorgName'] = doctor.thirdOrgName;
      result['thirdJdJgId'] = doctor.thirdOrgId;
      result['thirdJdJgIdName'] = doctor.thirdOrgName;
    }

    // 默认管理机构
    if (_isEmpty(result['manageOrgId']) || _isEmpty(result['thirdGldJgId'])) {
      result['manageOrgId'] = doctor.thirdOrgId;
      result['manageOrgName'] = doctor.thirdOrgName;
      result['thirdGldJgId'] = doctor.thirdOrgId;
      result['thirdGldJgIdName'] = doctor.thirdOrgName;
    }

    // 建档医生
    if (_isEmpty(result['thirdJdYsId'])) {
      result['thirdJdYsId'] = doctor.thirdUserId;
      result['thirdJdYsidName'] = doctor.thirdUserName;
    }

    // 责任医生
    if (_isEmpty(result['thirdZrysId'])) {
      result['thirdZrysId'] = doctor.thirdUserId;
      result['thirdZrysIdName'] = doctor.thirdUserName;
    }

    // 创建医生
    if (_isEmpty(result['thirdCuser'])) {
      result['thirdCuser'] = doctor.thirdUserId;
    }

    // 区划
    if (_isEmpty(result['areaCode'])) {
      result['areaCode'] = family['regionCode'];
    }

    // 云平台家庭id
    if (_isEmpty(result['thirdXjdJtId'])) {
      result['thirdXjdJtId'] = family['thirdXjdJtId'];
    }

    // 云平台档案ID
    if (_isEmpty(result['thirdDaId'])) {
      result['thirdDaId'] = family['thirdDaId'];
    }

    // 户籍地区划组编号
    if (_isEmpty(result['thirdHjdQhBh'])) {
      result['thirdHjdQhBh'] = family['regionCode'];
    }

    // 现居地区划组编号
    if (_isEmpty(result['thirdXjdQhjBh'])) {
      result['thirdXjdQhjBh'] = family['regionCode'];
    }

    return result;
  }

  bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String && value.isEmpty) return true;
    return false;
  }
}
