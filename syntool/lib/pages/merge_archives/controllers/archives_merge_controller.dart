import '../models/archives_enum_maps.dart';
import '../models/archives_merge_item.dart';
import '../models/archives_model.dart';

/// 档案合并控制器。
/// 负责字段展开、冲突识别、排序和已完善数据条数计算。
class ArchivesMergeController {
  const ArchivesMergeController();

  List<MergeItem> buildMergeItems({
    required ArchivesModel mainModel,
    required ArchivesModel auxiliaryModel,
  }) {
    final items = <MergeItem>[];

    items.addAll(_buildObjectMergeItems(
      module: FieldModule.familyInfo,
      prefix: 'familyInfo',
      main: mainModel.familyInfo,
      auxiliary: auxiliaryModel.familyInfo,
      fieldDefinitions: _familyInfoFields,
    ));

    items.addAll(_buildObjectMergeItems(
      module: FieldModule.personBaseInfo,
      prefix: 'personBaseInfo',
      main: mainModel.personBaseInfo,
      auxiliary: auxiliaryModel.personBaseInfo,
      fieldDefinitions: _personBaseInfoFields,
    ));

    items.addAll(_buildObjectMergeItems(
      module: FieldModule.livingEnvironment,
      prefix: 'livingEnvironment',
      main: mainModel.livingEnvironment,
      auxiliary: auxiliaryModel.livingEnvironment,
      fieldDefinitions: _livingEnvironmentFields,
    ));

    final historyItem = _buildArrayMergeItem(
      module: FieldModule.personHistoryList,
      fieldPath: 'personHistoryList',
      fieldName: '既往史',
      mainValue: mainModel.personHistoryList,
      auxiliaryValue: auxiliaryModel.personHistoryList,
    );
    _forceArrayItemType(
      historyItem,
      mainModel.personHistoryList,
      auxiliaryModel.personHistoryList,
      ArrayFieldType.personHistory,
    );
    items.add(historyItem);

    final familyHistoryItem = _buildArrayMergeItem(
      module: FieldModule.personFamilyHistoryList,
      fieldPath: 'personFamilyHistoryList',
      fieldName: '家族史',
      mainValue: mainModel.personFamilyHistoryList,
      auxiliaryValue: auxiliaryModel.personFamilyHistoryList,
    );
    _forceArrayItemType(
      familyHistoryItem,
      mainModel.personFamilyHistoryList,
      auxiliaryModel.personFamilyHistoryList,
      ArrayFieldType.personFamilyHistory,
    );
    items.add(familyHistoryItem);

    final illnessItem = _buildArrayMergeItem(
      module: FieldModule.personIllnessList,
      fieldPath: 'personIllnessList',
      fieldName: '遗传疾病史及残疾情况',
      mainValue: mainModel.personIllnessList,
      auxiliaryValue: auxiliaryModel.personIllnessList,
    );
    _forceArrayItemType(
      illnessItem,
      mainModel.personIllnessList,
      auxiliaryModel.personIllnessList,
      ArrayFieldType.personIllness,
    );
    items.add(illnessItem);

    for (final item in items) {
      switch (item.type) {
        case MergeItemType.mainOnly:
        case MergeItemType.equal:
          item.decision = MergeDecision.autoKept;
          break;
        case MergeItemType.auxiliaryOnly:
          item.decision = MergeDecision.keepAuxiliary;
          break;
        default:
          item.decision = MergeDecision.none;
      }
    }

    items.sort(_sortItems);
    return items;
  }

  /// 统计档案“已完善数据条数”。
  /// 仅按产品确认过的字段白名单计数，不复用合并展示字段，避免口径漂移。
  int calculateCompletedFieldCount(ArchivesModel model) {
    int count = 0;

    count += _countObjectFields(model.familyInfo, _familyInfoCountKeys);
    count += _countObjectFields(model.personBaseInfo, _personBaseInfoCountKeys);
    count += _countObjectFields(model.livingEnvironment, _livingEnvironmentCountKeys);
    count += _isValueValid(model.personHistoryList) ? 1 : 0;
    count += _isValueValid(model.personFamilyHistoryList) ? 1 : 0;
    count += _isValueValid(model.personIllnessList) ? 1 : 0;

    return count;
  }

  int _countObjectFields(dynamic object, List<String> fieldKeys) {
    final map = _objectToMap(object);
    int count = 0;
    for (final fieldKey in fieldKeys) {
      if (_isValueValid(map[fieldKey])) {
        count++;
      }
    }
    return count;
  }

  int _sortItems(MergeItem a, MergeItem b) {
    final orderA = _getSortOrder(a);
    final orderB = _getSortOrder(b);
    if (orderA != orderB) {
      return orderA.compareTo(orderB);
    }

    final moduleOrderA = _getModuleOrder(a.module);
    final moduleOrderB = _getModuleOrder(b.module);
    if (moduleOrderA != moduleOrderB) {
      return moduleOrderA.compareTo(moduleOrderB);
    }

    return a.fieldName.compareTo(b.fieldName);
  }

  int _getSortOrder(MergeItem item) {
    switch (item.type) {
      case MergeItemType.conflict:
        return item.isResolved ? 1 : 0;
      case MergeItemType.auxiliaryOnly:
        return 2;
      case MergeItemType.mainOnly:
      case MergeItemType.equal:
        return 3;
      default:
        return 4;
    }
  }

  int _getModuleOrder(FieldModule module) {
    switch (module) {
      case FieldModule.familyInfo:
        return 0;
      case FieldModule.personBaseInfo:
        return 1;
      case FieldModule.livingEnvironment:
        return 2;
      case FieldModule.personHistoryList:
        return 3;
      case FieldModule.personFamilyHistoryList:
        return 4;
      case FieldModule.personIllnessList:
        return 5;
    }
  }

  List<MergeItem> _buildObjectMergeItems({
    required FieldModule module,
    required String prefix,
    required dynamic main,
    required dynamic auxiliary,
    required List<_FieldDef> fieldDefinitions,
  }) {
    final items = <MergeItem>[];
    final mainMap = _objectToMap(main);
    final auxiliaryMap = _objectToMap(auxiliary);

    for (final def in fieldDefinitions) {
      items.add(
        MergeItem(
          uniqueKey: '$prefix.${def.key}',
          module: module,
          fieldName: def.name,
          fieldPath: '$prefix.${def.key}',
          mainValue: mainMap[def.key],
          auxiliaryValue: auxiliaryMap[def.key],
          enumMap: def.enumMap,
          isBitEnum: def.isBitEnum,
        ),
      );
    }

    return items;
  }

  MergeItem _buildArrayMergeItem({
    required FieldModule module,
    required String fieldPath,
    required String fieldName,
    required dynamic mainValue,
    required dynamic auxiliaryValue,
  }) {
    return MergeItem(
      uniqueKey: fieldPath,
      module: module,
      fieldName: fieldName,
      fieldPath: fieldPath,
      mainValue: _arrayToComparableList(mainValue),
      auxiliaryValue: _arrayToComparableList(auxiliaryValue),
      valueType: FieldValueType.object,
    );
  }

  List<Map<String, dynamic>> _arrayToComparableList(dynamic array) {
    if (array == null || array is! List || array.isEmpty) {
      return [];
    }

    return array.map((item) {
      if (item is Map<String, dynamic>) return item;
      if (item is PersonHistory) return item.toJson();
      if (item is PersonFamilyHistory) return item.toJson();
      if (item is PersonIllness) return item.toJson();
      return <String, dynamic>{};
    }).toList();
  }

  bool _arrayValuesEqual(dynamic a, dynamic b, ArrayFieldType type) {
    final listA = _arrayToComparableList(a);
    final listB = _arrayToComparableList(b);

    if (listA.length != listB.length) return false;
    if (listA.isEmpty && listB.isEmpty) return true;

    final usedIndexes = <int>{};
    for (final itemA in listA) {
      var matched = false;
      for (var index = 0; index < listB.length; index++) {
        if (usedIndexes.contains(index)) continue;
        if (_arrayItemEqual(itemA, listB[index], type)) {
          usedIndexes.add(index);
          matched = true;
          break;
        }
      }
      if (!matched) {
        return false;
      }
    }

    return usedIndexes.length == listB.length;
  }

  bool _arrayItemEqual(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    ArrayFieldType type,
  ) {
    switch (type) {
      case ArrayFieldType.personHistory:
        return _stringValue(a['recordType']) == _stringValue(b['recordType']) &&
            _stringValue(a['occurrenceDate']) == _stringValue(b['occurrenceDate']) &&
            _stringValue(a['name']) == _stringValue(b['name']) &&
            _stringValue(a['occurrenceDateOther']) ==
                _stringValue(b['occurrenceDateOther']);
      case ArrayFieldType.personFamilyHistory:
        return _intValue(a['disease']) == _intValue(b['disease']) &&
            _intValue(a['relationshipType']) == _intValue(b['relationshipType']) &&
            _stringValue(a['remark']) == _stringValue(b['remark']);
      case ArrayFieldType.personIllness:
        return _intValue(a['diseaseKindId']) == _intValue(b['diseaseKindId']) &&
            _stringValue(a['remark']) == _stringValue(b['remark']) &&
            _stringValue(a['diagnosisDate']) == _stringValue(b['diagnosisDate']) &&
            _stringValue(a['recordDate']) == _stringValue(b['recordDate']) &&
            _stringValue(a['diagnosisDateOther']) ==
                _stringValue(b['diagnosisDateOther']);
    }
  }

  void _forceArrayItemType(
    MergeItem item,
    dynamic mainValue,
    dynamic auxiliaryValue,
    ArrayFieldType type,
  ) {
    final mainValid = _isValueValid(mainValue);
    final auxiliaryValid = _isValueValid(auxiliaryValue);

    if (!mainValid && !auxiliaryValid) {
      item.forceType(MergeItemType.bothEmpty);
    } else if (mainValid && !auxiliaryValid) {
      item.forceType(MergeItemType.mainOnly);
    } else if (!mainValid && auxiliaryValid) {
      item.forceType(MergeItemType.auxiliaryOnly);
    } else if (_arrayValuesEqual(mainValue, auxiliaryValue, type)) {
      item.forceType(MergeItemType.equal);
    } else {
      item.forceType(MergeItemType.conflict);
    }
  }

  Map<String, dynamic> _objectToMap(dynamic object) {
    if (object == null) return <String, dynamic>{};
    if (object is Map<String, dynamic>) return object;
    try {
      return (object as dynamic).toJson() as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  bool _isValueValid(dynamic value) {
    if (value == null) return false;
    if (value is String && value.trim().isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    if (value is Map && value.isEmpty) return false;
    return true;
  }

  String _stringValue(dynamic value) => value?.toString() ?? '';

  int? _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

enum ArrayFieldType {
  personHistory,
  personFamilyHistory,
  personIllness,
}

class _FieldDef {
  final String key;
  final String name;
  final Map<dynamic, String>? enumMap;
  final bool isBitEnum;

  const _FieldDef(
    this.key,
    this.name, {
    this.enumMap,
    this.isBitEnum = false,
  });
}

const List<_FieldDef> _familyInfoFields = [
  _FieldDef('familyAddress', '家庭地址'),
  _FieldDef('familyTel', '家庭电话'),
  _FieldDef('memberCount', '家庭人口数'),
  _FieldDef('currentCount', '现住人口数'),
  _FieldDef('disabilityCount', '残疾人人数'),
  _FieldDef('montyAverageIncome', '月均收入'),
  _FieldDef('yearAverageIncome', '年均收入'),
  _FieldDef('houseArea', '住房使用面积'),
  _FieldDef('houseType', '住房类型', enumMap: houseTypeMap),
  _FieldDef('houseSituation', '住房情况', enumMap: houseSituationMap),
  _FieldDef('houseDaylighting', '住房采光', enumMap: houseDaylightingMap),
  _FieldDef('kitchenExhaust', '厨房排风设施', enumMap: kitchenExhaustMap),
  _FieldDef('haveIcebox', '有无冰箱', enumMap: haveIceboxMap),
  _FieldDef('fuelType', '燃料类型', enumMap: fuelTypeMap),
  _FieldDef('waterType', '饮水类型', enumMap: waterTypeMap),
  _FieldDef('toiletType', '厕所类型', enumMap: toiletTypeMap),
  _FieldDef('livestockColumn', '禽畜栏', enumMap: livestockColumnMap),
  _FieldDef('position', '家庭位置', enumMap: positionMap),
  _FieldDef('tomarket', '距商场(km)'),
  _FieldDef('policeStation', '距派出所(km)'),
  _FieldDef('policeNumber', '公安号'),
  _FieldDef('salcro', '家庭属性', enumMap: salcroMap, isBitEnum: true),
  _FieldDef('remark', '备注'),
  _FieldDef('buildDate', '建档时间'),
  _FieldDef('buildStaffName', '建档医生'),
  _FieldDef('maxMemberCount', '最大成员数'),
  _FieldDef('regionCode', '家庭区划'),
  _FieldDef('regionCodeFullName', '区划全名'),
  _FieldDef('countyCommittee', '所属居委会'),
  _FieldDef('masterName', '户主姓名'),
  _FieldDef('masterCardId', '户主身份证号'),
  _FieldDef('masterGender', '户主性别'),
];

const List<_FieldDef> _personBaseInfoFields = [
  _FieldDef('name', '姓名'),
  _FieldDef('idCard', '身份证号码'),
  _FieldDef('gender', '性别', enumMap: genderMap),
  _FieldDef('birthDay', '出生日期'),
  _FieldDef('nation', '民族', enumMap: nationMap),
  _FieldDef('phoneNumber', '本人电话'),
  _FieldDef('profilePhoto', '头像'),
  _FieldDef('residenceAddress', '户籍地址'),
  _FieldDef('address', '现住地址'),
  _FieldDef('resType', '户籍类别', enumMap: resTypeMap),
  _FieldDef('hukouFlag', '常住类型', enumMap: hukouFlagMap),
  _FieldDef('residenceCycleType', '居住类型', enumMap: residenceCycleTypeMap),
  _FieldDef('workOrgName', '工作单位'),
  _FieldDef('jobCode', '职业', enumMap: jobCodeMap),
  _FieldDef('jobCodeOther', '职业其他'),
  _FieldDef('jobCodeSpecial', '职业特殊分类', enumMap: jobCodeSpecialMap),
  _FieldDef('contactPerson', '联系人姓名'),
  _FieldDef('contactTel', '联系人电话'),
  _FieldDef(
    'contactRelationship',
    '联系人关系',
    enumMap: householderRelationshipMap,
  ),
  _FieldDef('contactPerson2', '联系人姓名2'),
  _FieldDef('contactTel2', '联系人电话2'),
  _FieldDef(
    'contactRelationship2',
    '联系人关系2',
    enumMap: householderRelationshipMap,
  ),
  _FieldDef('bloodType', '血型', enumMap: bloodTypeMap),
  _FieldDef('rhBlood', 'RH血型', enumMap: rhBloodMap),
  _FieldDef('education', '文化程度', enumMap: educationMap),
  _FieldDef('marryStatus', '婚姻状况', enumMap: marryStatusMap),
  _FieldDef('isFlowing', '是否流动人口', enumMap: isFlowingMap),
  _FieldDef('isPoor', '是否贫困人口', enumMap: isPoorMap),
  _FieldDef(
    'paymentWaystring',
    '医疗费用支付方式',
    enumMap: paymentWaystringMap,
    isBitEnum: true,
  ),
  _FieldDef('otherPaymentWaystring', '其他支付方式'),
  _FieldDef(
    'drugAllergyHistory',
    '药物过敏史',
    enumMap: drugAllergyHistoryMap,
    isBitEnum: true,
  ),
  _FieldDef('foodAllergyHistoryRemark', '食物过敏史'),
  _FieldDef('otherDrugAllergyHistoryRemark', '其他药物过敏史'),
  _FieldDef('otherDrugAllergyHistory', '其他过敏史'),
  _FieldDef(
    'exposureHistory',
    '暴露历史',
    enumMap: exposureHistoryMap,
    isBitEnum: true,
  ),
  _FieldDef('isFamilyPlanning', '是否计生家庭', enumMap: isFamilyPlanningMap),
  _FieldDef('status', '档案状态', enumMap: statusMap),
  _FieldDef('statusRemark', '状态变更说明'),
  _FieldDef('deathCause', '死亡原因'),
  _FieldDef('customNumber', '自定义编号'),
  _FieldDef('buildOrgId', '建档机构ID'),
  _FieldDef('buildOrgName', '建档机构'),
  _FieldDef('manageOrgId', '管理机构ID'),
  _FieldDef('manageOrgName', '管理机构'),
  _FieldDef('buildEmployeeId', '建档人ID'),
  _FieldDef('buildEmployeeName', '建档人姓名'),
  _FieldDef('createDate', '建档日期'),
  _FieldDef('responsibilityId', '责任人ID'),
  _FieldDef('responsibilityDoctor', '责任人姓名'),
  _FieldDef('disability', '残疾情况', enumMap: disabilityMap, isBitEnum: true),
  _FieldDef('disabilityNumber', '残疾证号'),
  _FieldDef('otherDisability', '其他残疾'),
  _FieldDef('tags', '健康档案标签'),
  _FieldDef('personCode', '人员编号'),
  _FieldDef('workDate', '参加工作时间'),
  _FieldDef('regionCode', '区划'),
  _FieldDef('placeOriginCode', '籍贯Code'),
  _FieldDef('placeOrigin', '籍贯'),
  _FieldDef('birthPlaceCode', '出生地Code'),
  _FieldDef('birthPlace', '出生地'),
  _FieldDef('areaCode', '区划'),
  _FieldDef(
    'householderRelationship',
    '户主关系',
    enumMap: householderRelationshipMap,
  ),
  _FieldDef('updated', '更新时间'),
];

const List<_FieldDef> _livingEnvironmentFields = [
  _FieldDef(
    'kitchenExhaust',
    '厨房排风设施',
    enumMap: livingKitchenExhaustMap,
    isBitEnum: true,
  ),
  _FieldDef('fuelType', '燃料类型', enumMap: livingFuelTypeMap, isBitEnum: true),
  _FieldDef(
    'drinkingwater',
    '饮水类型',
    enumMap: drinkingwaterMap,
    isBitEnum: true,
  ),
  _FieldDef('toilet', '厕所类型', enumMap: toiletMap),
  _FieldDef(
    'livestockColumn',
    '禽畜栏',
    enumMap: livingLivestockColumnMap,
    isBitEnum: true,
  ),
];

const List<String> _familyInfoCountKeys = [
  'customNumber',
  'regionCode',
  'memberCount',
  'currentCount',
  'tomarket',
  'policeNumber',
  'salcro',
  'remark',
  'disabilityCount',
  'familyTel',
  'montyAverageIncome',
  'position',
  'yearAverageIncome',
  'houseArea',
  'tohealthstation',
  'tohospitals',
  'regionCodeFullName',
  'familyAddress',
  'houseType',
  'houseSituation',
  'houseDaylighting',
  'kitchenExhaust',
  'haveIcebox',
  'fuelType',
  'waterType',
  'toiletType',
  'livestockColumn',
  'buildDate',
  'buildStaffName',
  'maxMemberCount',
  'buildStaffId',
  'buildOrgName',
  'countyCommittee',
  'masterName',
];

const List<String> _personBaseInfoCountKeys = [
  'areaCode',
  'householderRelationship',
  'name',
  'profilePhoto',
  'phoneNumber',
  'idCard',
  'birthDay',
  'gender',
  'nation',
  'residenceAddress',
  'resType',
  'address',
  'hukouFlag',
  'residenceCycleType',
  'workOrgName',
  'jobCode',
  'jobCodeOther',
  'contactPerson',
  'contactTel',
  'bloodType',
  'rhBlood',
  'education',
  'marryStatus',
  'isFlowing',
  'isPoor',
  'paymentWaystring',
  'otherPaymentWaystring',
  'drugAllergyHistory',
  'foodAllergyHistoryRemark',
  'otherDrugAllergyHistoryRemark',
  'otherDrugAllergyHistory',
  'exposureHistory',
  'isFamilyPlanning',
  'status',
  'updated',
  'statusRemark',
  'deathCause',
  'customNumber',
  'buildOrgId',
  'manageOrgId',
  'buildEmployeeId',
  'createDate',
  'responsibilityId',
  'disability',
  'disabilityNumber',
  'otherDisability',
  'jobCodeSpecial',
  'certificateCardList',
  'tags',
  'personCode',
  'workDate',
  'regionCode',
  'placeOriginCode',
  'birthPlaceCode',
  'contactRelationship',
  'contactPerson2',
  'contactTel2',
  'contactRelationship2',
];

const List<String> _livingEnvironmentCountKeys = [
  'kitchenExhaust',
  'fuelType',
  'drinkingwater',
  'toilet',
  'livestockColumn',
];
