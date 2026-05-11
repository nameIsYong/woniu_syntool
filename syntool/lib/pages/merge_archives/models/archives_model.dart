/// 档案模型
class ArchivesModel {
  /// 家庭信息
  FamilyBaseInfoModel? familyInfo;

  /// 居民基本信息
  PersonBaseInfo? personBaseInfo;

  /// 既往史
  List<PersonHistory> personHistoryList = [];

  /// 家族史
  List<PersonFamilyHistory> personFamilyHistoryList = [];

  /// 遗传疾病史及残疾情况（疾病史）
  List<PersonIllness> personIllnessList = [];

  /// 生活环境
  LivingEnvironment? livingEnvironment;

  /// 扩展数据
  Map<String, dynamic> personBaseExtendsInfo = {};

  ArchivesModel();

  factory ArchivesModel.fromJson(Map<String, dynamic> json) {
    final model = ArchivesModel();
    model.familyInfo = json['familyInfo'] != null
        ? FamilyBaseInfoModel.fromJson(json['familyInfo'] as Map<String, dynamic>)
        : null;
    model.personBaseInfo = json['personBaseInfo'] != null
        ? PersonBaseInfo.fromJson(json['personBaseInfo'] as Map<String, dynamic>)
        : null;
    if (json['personHistoryList'] is List) {
      model.personHistoryList = (json['personHistoryList'] as List)
          .map((e) => PersonHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (json['personFamilyHistoryList'] is List) {
      model.personFamilyHistoryList = (json['personFamilyHistoryList'] as List)
          .map((e) => PersonFamilyHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (json['personIllnessList'] is List) {
      model.personIllnessList = (json['personIllnessList'] as List)
          .map((e) => PersonIllness.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    model.livingEnvironment = json['livingEnvironment'] != null
        ? LivingEnvironment.fromJson(json['livingEnvironment'] as Map<String, dynamic>)
        : null;
    if (json['personBaseExtendsInfo'] is Map) {
      model.personBaseExtendsInfo = Map<String, dynamic>.from(json['personBaseExtendsInfo'] as Map);
    }
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'familyInfo': familyInfo?.toJson(),
      'personBaseInfo': personBaseInfo?.toJson(),
      'personHistoryList': personHistoryList.map((e) => e.toJson()).toList(),
      'personFamilyHistoryList': personFamilyHistoryList.map((e) => e.toJson()).toList(),
      'personIllnessList': personIllnessList.map((e) => e.toJson()).toList(),
      'livingEnvironment': livingEnvironment?.toJson(),
      'personBaseExtendsInfo': personBaseExtendsInfo,
    };
  }
}

/// 家庭信息
class FamilyBaseInfoModel {
  /// 家庭档案ID
  String id = '';

  /// 自定义编号
  String customNumber = '';

  /// 家庭区划（选择）
  String regionCode = '';

  /// 家庭人口数
  String memberCount = '';

  /// 现住人口数
  String currentCount = '';

  /// 距商场-单位km（云平台新增）
  String tomarket = '';

  /// 距派出所-单位km
  String policeStation = '';

  /// 公安号（云平台新增）
  String policeNumber = '';

  /// 云平台为家庭属性
  String salcro = '';

  /// 备注
  String remark = '';

  /// 残疾人人数
  String disabilityCount = '';

  /// 家庭电话
  String familyTel = '';

  /// 月均收入-单位元
  String montyAverageIncome = '';

  /// 家庭位置(0未知，1集居，2孤居)
  String position = '';

  /// 年均收入-单位元
  String yearAverageIncome = '';

  /// 住房使用面积-单位平方
  String houseArea = '';

  /// 距卫生站-单位km
  String tohealthstation = '';

  /// 距卫生院-单位km
  String tohospitals = '';

  /// 家庭区划全名
  String regionCodeFullName = '';

  /// 家庭地址
  String familyAddress = '';

  /// 云平台（0 其他，1 砖瓦平房，2 高层楼房，4 普通楼房，5 木棚土坯平房）
  String houseType = '';

  /// 住房情况（云平台新增）
  String houseSituation = '';

  /// 住房采光（云平台新增）
  String houseDaylighting = '';

  /// 厨房排风设施(1 无, 2 油烟机, 4 换气扇,8 烟囱)
  String kitchenExhaust = '';

  /// 有无冰箱（0 无，1有 ）
  String haveIcebox = '';

  /// 云平台补充（0:未知，1 液化气，2 煤，3天然气，4 沼气，5 柴火，6 其他）
  String fuelType = '';

  /// 云平台补充（0 未知，1 自来水，2 净化过滤的水，3 井水，4 河湖水，5 塘水，6 其他）
  String waterType = '';

  /// 云平台（0 未知，1卫生厕所，2 一格或二格粪池式，3 马桶，4 露天粪坑，5 简易棚厕）
  String toiletType = '';

  /// 禽畜栏（0 无，1 单设，2 室内，4 室外）
  String livestockColumn = '';

  /// 建档时间
  String buildDate = '';

  /// 建档机构名称
  String buildStaffName = '';

  /// 最大成员数
  String maxMemberCount = '';

  /// 数据状态
  String dataStatus = '';

  /// 建档医生ID
  String buildStaffId = '';

  String idFiled = '';

  /// 户主档案ID
  String masterId = '';

  /// 建档机构ID
  String buildOrgId = '';

  /// 建档机构名
  String buildOrgName = '';

  /// 所属居委会
  String countyCommittee = '';

  /// 更新时间
  String update = '';

  /// 1：被编辑过，0：没有被编辑过
  int? editing;

  /// 1：临时档案，2：非临时档案
  int? tempArchives;

  /// 户主姓名
  String masterName = '';

  /// 户主ID
  String masterCardId = '';

  /// 户主性别
  String masterGender = '';

  /// 户主身份证号
  String thirdCuser = '';
  String thirdCorg = '';
  String thirdMuser = '';
  String thirdMorgId = '';
  String thirdDuser = '';
  String thirdRbh = '';
  String thirdJbh = '';

  /// 云平台家庭id(已同步的家庭才有此值)
  String thirdXjdJtId = '';

  /// 云平台该居民在云平台的档案ID
  String thirdDaId = '';

  FamilyBaseInfoModel();

  factory FamilyBaseInfoModel.fromJson(Map<String, dynamic> json) {
    final model = FamilyBaseInfoModel();
    model.id = _stringVal(json['id']);
    model.customNumber = _stringVal(json['customNumber']);
    model.regionCode = _stringVal(json['regionCode']);
    model.memberCount = _stringVal(json['memberCount']);
    model.currentCount = _stringVal(json['currentCount']);
    model.tomarket = _stringVal(json['tomarket']);
    model.policeStation = _stringVal(json['policeStation']);
    model.policeNumber = _stringVal(json['policeNumber']);
    model.salcro = _stringVal(json['salcro']);
    model.remark = _stringVal(json['remark']);
    model.disabilityCount = _stringVal(json['disabilityCount']);
    model.familyTel = _stringVal(json['familyTel']);
    model.montyAverageIncome = _stringVal(json['montyAverageIncome']);
    model.position = _stringVal(json['position']);
    model.yearAverageIncome = _stringVal(json['yearAverageIncome']);
    model.houseArea = _stringVal(json['houseArea']);
    model.tohealthstation = _stringVal(json['tohealthstation']);
    model.tohospitals = _stringVal(json['tohospitals']);
    model.regionCodeFullName = _stringVal(json['regionCodeFullName']);
    model.familyAddress = _stringVal(json['familyAddress']);
    model.houseType = _stringVal(json['houseType']);
    model.houseSituation = _stringVal(json['houseSituation']);
    model.houseDaylighting = _stringVal(json['houseDaylighting']);
    model.kitchenExhaust = _stringVal(json['kitchenExhaust']);
    model.haveIcebox = _stringVal(json['haveIcebox']);
    model.fuelType = _stringVal(json['fuelType']);
    model.waterType = _stringVal(json['waterType']);
    model.toiletType = _stringVal(json['toiletType']);
    model.livestockColumn = _stringVal(json['livestockColumn']);
    model.buildDate = _stringVal(json['buildDate']);
    model.buildStaffName = _stringVal(json['buildStaffName']);
    model.maxMemberCount = _stringVal(json['maxMemberCount']);
    model.dataStatus = _stringVal(json['dataStatus']);
    model.buildStaffId = _stringVal(json['buildStaffId']);
    model.idFiled = _stringVal(json['idFiled']);
    model.masterId = _stringVal(json['masterId']);
    model.buildOrgId = _stringVal(json['buildOrgId']);
    model.buildOrgName = _stringVal(json['buildOrgName']);
    model.countyCommittee = _stringVal(json['countyCommittee']);
    model.update = _stringVal(json['update']);
    model.editing = json['editing'] as int?;
    model.tempArchives = json['tempArchives'] as int?;
    model.masterName = _stringVal(json['masterName']);
    model.masterCardId = _stringVal(json['masterCardId']);
    model.masterGender = _stringVal(json['masterGender']);
    model.thirdCuser = _stringVal(json['thirdCuser']);
    model.thirdCorg = _stringVal(json['thirdCorg']);
    model.thirdMuser = _stringVal(json['thirdMuser']);
    model.thirdMorgId = _stringVal(json['thirdMorgId']);
    model.thirdDuser = _stringVal(json['thirdDuser']);
    model.thirdRbh = _stringVal(json['thirdRbh']);
    model.thirdJbh = _stringVal(json['thirdJbh']);
    model.thirdXjdJtId = _stringVal(json['thirdXjdJtId']);
    model.thirdDaId = _stringVal(json['thirdDaId']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customNumber': customNumber,
      'regionCode': regionCode,
      'memberCount': memberCount,
      'currentCount': currentCount,
      'tomarket': tomarket,
      'policeStation': policeStation,
      'policeNumber': policeNumber,
      'salcro': salcro,
      'remark': remark,
      'disabilityCount': disabilityCount,
      'familyTel': familyTel,
      'montyAverageIncome': montyAverageIncome,
      'position': position,
      'yearAverageIncome': yearAverageIncome,
      'houseArea': houseArea,
      'tohealthstation': tohealthstation,
      'tohospitals': tohospitals,
      'regionCodeFullName': regionCodeFullName,
      'familyAddress': familyAddress,
      'houseType': houseType,
      'houseSituation': houseSituation,
      'houseDaylighting': houseDaylighting,
      'kitchenExhaust': kitchenExhaust,
      'haveIcebox': haveIcebox,
      'fuelType': fuelType,
      'waterType': waterType,
      'toiletType': toiletType,
      'livestockColumn': livestockColumn,
      'buildDate': buildDate,
      'buildStaffName': buildStaffName,
      'maxMemberCount': maxMemberCount,
      'dataStatus': dataStatus,
      'buildStaffId': buildStaffId,
      'idFiled': idFiled,
      'masterId': masterId,
      'buildOrgId': buildOrgId,
      'buildOrgName': buildOrgName,
      'countyCommittee': countyCommittee,
      'update': update,
      'editing': editing,
      'tempArchives': tempArchives,
      'masterName': masterName,
      'masterCardId': masterCardId,
      'masterGender': masterGender,
      'thirdCuser': thirdCuser,
      'thirdCorg': thirdCorg,
      'thirdMuser': thirdMuser,
      'thirdMorgId': thirdMorgId,
      'thirdDuser': thirdDuser,
      'thirdRbh': thirdRbh,
      'thirdJbh': thirdJbh,
      'thirdXjdJtId': thirdXjdJtId,
      'thirdDaId': thirdDaId,
    };
  }
}

/// 建档信息
class PersonBaseInfo {
  /// 档案ID
  String residentHealthRecordId = '';

  /// 家庭档案ID
  String familyId = '';

  /// 区划
  String areaCode = '';

  /// 户主关系
  String householderRelationship = '';

  /// 姓名
  String name = '';

  /// 头像
  String profilePhoto = '';

  /// 本人电话
  String phoneNumber = '';

  /// 身份证号码
  String idCard = '';

  /// 出生日期
  String birthDay = '';

  /// 性别 0未知,1男,2女,9未说明的性别
  int? gender;

  /// 民族
  int? nation;

  /// 户籍地址
  String residenceAddress = '';

  /// 户籍类别 1农业,2非农业
  int? resType;

  /// 现住地址
  String address = '';

  /// 常住类型 1户籍,2非户籍
  String hukouFlag = '';

  /// 居住（周期）类型 1常住，2暂住，3流动，4 其他
  String residenceCycleType = '';

  /// 工作单位
  String workOrgName = '';

  /// 职业代码
  String jobCode = '';

  /// 职业内容其他
  String jobCodeOther = '';

  /// 联系人姓名
  String contactPerson = '';

  /// 联系人电话
  String contactTel = '';

  /// 血型 1 A型,2 B型,3 o型,4 AB型, 5 不详
  String bloodType = '';

  /// RH阴性 1 阳性,2 阴性,3 不详
  String rhBlood = '';

  /// 文化程度
  String education = '';

  /// 婚姻状况
  String marryStatus = '';

  /// 是否流动人口 0不是，1是
  String isFlowing = '';

  /// 是否贫困人口 1否，2是
  String isPoor = '';

  /// 医疗费用支付方式
  int? paymentWaystring;

  /// 其他支付方式
  String otherPaymentWaystring = '';

  /// 药物过敏史
  int? drugAllergyHistory;

  /// 食物过敏史
  String foodAllergyHistoryRemark = '';

  /// 其他药物过敏史
  String otherDrugAllergyHistoryRemark = '';

  /// 其他过敏史
  String otherDrugAllergyHistory = '';

  /// 暴露历史
  int? exposureHistory;

  /// 是否计生家庭
  int? isFamilyPlanning;

  /// 档案状态
  String status = '';

  /// 聊天ID
  String userId = '';

  /// 档案更新时间
  String updated = '';

  /// 档案状态变更说明
  String statusRemark = '';

  /// 死亡原因
  String deathCause = '';

  /// 自定义编号
  String customNumber = '';

  /// 建档机构Id
  String buildOrgId = '';

  /// 建档机构
  String buildOrgName = '';

  /// 管理机构ID
  String manageOrgId = '';

  /// 管理机构
  String manageOrgName = '';

  /// 建档人ID
  String buildEmployeeId = '';

  /// 建档人姓名
  String buildEmployeeName = '';

  /// 建档日期
  String createDate = '';

  /// 责任人ID
  String responsibilityId = '';

  /// 责任人姓名
  String responsibilityDoctor = '';

  /// 残疾情况
  String disability = '';

  /// 残疾证号
  String disabilityNumber = '';

  /// 其他残疾名称
  String otherDisability = '';

  /// 职业不便分类的选项
  int? jobCodeSpecial;

  /// 证件照列表
  List<CertificateCard> certificateCardList = [];

  /// 健康档案标签，慢病标签
  String tags = '';

  /// 人员编号
  String personCode = '';

  /// 参加工作时间
  String workDate = '';

  /// 区划
  String regionCode = '';

  /// 籍贯Code
  String placeOriginCode = '';

  /// 籍贯
  String placeOrigin = '';

  /// 出生地code
  String birthPlaceCode = '';

  /// 出生地
  String birthPlace = '';

  /// 联系人关系
  String contactRelationship = '';

  /// 联系人姓名2
  String contactPerson2 = '';

  /// 联系人电话2
  String contactTel2 = '';

  /// 联系人关系2
  String contactRelationship2 = '';

  PersonBaseInfo();

  factory PersonBaseInfo.fromJson(Map<String, dynamic> json) {
    final model = PersonBaseInfo();
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.familyId = _stringVal(json['familyId']);
    model.areaCode = _stringVal(json['areaCode']);
    model.householderRelationship = _stringVal(json['householderRelationship']);
    model.name = _stringVal(json['name']);
    model.profilePhoto = _stringVal(json['profilePhoto']);
    model.phoneNumber = _stringVal(json['phoneNumber']);
    model.idCard = _stringVal(json['idCard']);
    model.birthDay = _stringVal(json['birthDay']);
    model.gender = json['gender'] as int?;
    model.nation = json['nation'] as int?;
    model.residenceAddress = _stringVal(json['residenceAddress']);
    model.resType = json['resType'] as int?;
    model.address = _stringVal(json['address']);
    model.hukouFlag = _stringVal(json['hukouFlag']);
    model.residenceCycleType = _stringVal(json['residenceCycleType']);
    model.workOrgName = _stringVal(json['workOrgName']);
    model.jobCode = _stringVal(json['jobCode']);
    model.jobCodeOther = _stringVal(json['jobCodeOther']);
    model.contactPerson = _stringVal(json['contactPerson']);
    model.contactTel = _stringVal(json['contactTel']);
    model.bloodType = _stringVal(json['bloodType']);
    model.rhBlood = _stringVal(json['rhBlood']);
    model.education = _stringVal(json['education']);
    model.marryStatus = _stringVal(json['marryStatus']);
    model.isFlowing = _stringVal(json['isFlowing']);
    model.isPoor = _stringVal(json['isPoor']);
    model.paymentWaystring = json['paymentWaystring'] as int?;
    model.otherPaymentWaystring = _stringVal(json['otherPaymentWaystring']);
    model.drugAllergyHistory = json['drugAllergyHistory'] as int?;
    model.foodAllergyHistoryRemark = _stringVal(json['foodAllergyHistoryRemark']);
    model.otherDrugAllergyHistoryRemark = _stringVal(json['otherDrugAllergyHistoryRemark']);
    model.otherDrugAllergyHistory = _stringVal(json['otherDrugAllergyHistory']);
    model.exposureHistory = json['exposureHistory'] as int?;
    model.isFamilyPlanning = json['isFamilyPlanning'] as int?;
    model.status = _stringVal(json['status']);
    model.userId = _stringVal(json['userId']);
    model.updated = _stringVal(json['updated']);
    model.statusRemark = _stringVal(json['statusRemark']);
    model.deathCause = _stringVal(json['deathCause']);
    model.customNumber = _stringVal(json['customNumber']);
    model.buildOrgId = _stringVal(json['buildOrgId']);
    model.buildOrgName = _stringVal(json['buildOrgName']);
    model.manageOrgId = _stringVal(json['manageOrgId']);
    model.manageOrgName = _stringVal(json['manageOrgName']);
    model.buildEmployeeId = _stringVal(json['buildEmployeeId']);
    model.buildEmployeeName = _stringVal(json['buildEmployeeName']);
    model.createDate = _stringVal(json['createDate']);
    model.responsibilityId = _stringVal(json['responsibilityId']);
    model.responsibilityDoctor = _stringVal(json['responsibilityDoctor']);
    model.disability = _stringVal(json['disability']);
    model.disabilityNumber = _stringVal(json['disabilityNumber']);
    model.otherDisability = _stringVal(json['otherDisability']);
    model.jobCodeSpecial = json['jobCodeSpecial'] as int?;
    if (json['certificateCardList'] is List) {
      model.certificateCardList = (json['certificateCardList'] as List)
          .map((e) => CertificateCard.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    model.tags = _stringVal(json['tags']);
    model.personCode = _stringVal(json['personCode']);
    model.workDate = _stringVal(json['workDate']);
    model.regionCode = _stringVal(json['regionCode']);
    model.placeOriginCode = _stringVal(json['placeOriginCode']);
    model.placeOrigin = _stringVal(json['placeOrigin']);
    model.birthPlaceCode = _stringVal(json['birthPlaceCode']);
    model.birthPlace = _stringVal(json['birthPlace']);
    model.contactRelationship = _stringVal(json['contactRelationship']);
    model.contactPerson2 = _stringVal(json['contactPerson2']);
    model.contactTel2 = _stringVal(json['contactTel2']);
    model.contactRelationship2 = _stringVal(json['contactRelationship2']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'residentHealthRecordId': residentHealthRecordId,
      'familyId': familyId,
      'areaCode': areaCode,
      'householderRelationship': householderRelationship,
      'name': name,
      'profilePhoto': profilePhoto,
      'phoneNumber': phoneNumber,
      'idCard': idCard,
      'birthDay': birthDay,
      'gender': gender,
      'nation': nation,
      'residenceAddress': residenceAddress,
      'resType': resType,
      'address': address,
      'hukouFlag': hukouFlag,
      'residenceCycleType': residenceCycleType,
      'workOrgName': workOrgName,
      'jobCode': jobCode,
      'jobCodeOther': jobCodeOther,
      'contactPerson': contactPerson,
      'contactTel': contactTel,
      'bloodType': bloodType,
      'rhBlood': rhBlood,
      'education': education,
      'marryStatus': marryStatus,
      'isFlowing': isFlowing,
      'isPoor': isPoor,
      'paymentWaystring': paymentWaystring,
      'otherPaymentWaystring': otherPaymentWaystring,
      'drugAllergyHistory': drugAllergyHistory,
      'foodAllergyHistoryRemark': foodAllergyHistoryRemark,
      'otherDrugAllergyHistoryRemark': otherDrugAllergyHistoryRemark,
      'otherDrugAllergyHistory': otherDrugAllergyHistory,
      'exposureHistory': exposureHistory,
      'isFamilyPlanning': isFamilyPlanning,
      'status': status,
      'userId': userId,
      'updated': updated,
      'statusRemark': statusRemark,
      'deathCause': deathCause,
      'customNumber': customNumber,
      'buildOrgId': buildOrgId,
      'buildOrgName': buildOrgName,
      'manageOrgId': manageOrgId,
      'manageOrgName': manageOrgName,
      'buildEmployeeId': buildEmployeeId,
      'buildEmployeeName': buildEmployeeName,
      'createDate': createDate,
      'responsibilityId': responsibilityId,
      'responsibilityDoctor': responsibilityDoctor,
      'disability': disability,
      'disabilityNumber': disabilityNumber,
      'otherDisability': otherDisability,
      'jobCodeSpecial': jobCodeSpecial,
      'certificateCardList': certificateCardList.map((e) => e.toJson()).toList(),
      'tags': tags,
      'personCode': personCode,
      'workDate': workDate,
      'regionCode': regionCode,
      'placeOriginCode': placeOriginCode,
      'placeOrigin': placeOrigin,
      'birthPlaceCode': birthPlaceCode,
      'birthPlace': birthPlace,
      'contactRelationship': contactRelationship,
      'contactPerson2': contactPerson2,
      'contactTel2': contactTel2,
      'contactRelationship2': contactRelationship2,
    };
  }
}

/// 证件列表
class CertificateCard {
  /// 居民档案ID
  String residentHealthRecordId = '';

  /// 证件类型
  int? certificateType;

  /// 证件号码
  String certificateNumber = '';

  /// 创建时间
  String createTime = '';

  /// 证件照
  String certificatePhotos = '';

  CertificateCard();

  factory CertificateCard.fromJson(Map<String, dynamic> json) {
    final model = CertificateCard();
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.certificateType = json['certificateType'] as int?;
    model.certificateNumber = _stringVal(json['certificateNumber']);
    model.createTime = _stringVal(json['createTime']);
    model.certificatePhotos = _stringVal(json['certificatePhotos']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'residentHealthRecordId': residentHealthRecordId,
      'certificateType': certificateType,
      'certificateNumber': certificateNumber,
      'createTime': createTime,
      'certificatePhotos': certificatePhotos,
    };
  }
}

/// 居民个人既往史
class PersonHistory {
  /// 既往史记录id
  int? id;

  /// 档案ID
  String residentHealthRecordId = '';

  /// 类型:1手术 2外伤 3输血 4遗传病史
  int? recordType;

  /// 名称
  String name = '';

  /// 编码
  String code = '';

  /// 值
  String value = '';

  /// 发生日期
  String occurrenceDate = '';

  /// 1-表示不详
  String occurrenceDateOther = '';

  PersonHistory();

  factory PersonHistory.fromJson(Map<String, dynamic> json) {
    final model = PersonHistory();
    model.id = json['id'] as int?;
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.recordType = json['recordType'] as int?;
    model.name = _stringVal(json['name']);
    model.code = _stringVal(json['code']);
    model.value = _stringVal(json['value']);
    model.occurrenceDate = _stringVal(json['occurrenceDate']);
    model.occurrenceDateOther = _stringVal(json['occurrenceDateOther']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentHealthRecordId': residentHealthRecordId,
      'recordType': recordType,
      'name': name,
      'code': code,
      'value': value,
      'occurrenceDate': occurrenceDate,
      'occurrenceDateOther': occurrenceDateOther,
    };
  }
}

/// 居民家族史
class PersonFamilyHistory {
  /// 家族史记录ID
  int id = 0;

  /// 档案ID
  String residentHealthRecordId = '';

  /// 关系类型:1父亲,2母亲,3兄弟姐妹,4子女
  int? relationshipType;

  /// 疾病:位运算组合值
  int? disease;

  /// 其他信息
  String remark = '';

  PersonFamilyHistory();

  factory PersonFamilyHistory.fromJson(Map<String, dynamic> json) {
    final model = PersonFamilyHistory();
    model.id = json['id'] as int? ?? 0;
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.relationshipType = json['relationshipType'] as int?;
    model.disease = json['disease'] as int?;
    model.remark = _stringVal(json['remark']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentHealthRecordId': residentHealthRecordId,
      'relationshipType': relationshipType,
      'disease': disease,
      'remark': remark,
    };
  }
}

/// 疾病史
class PersonIllness {
  /// 遗传疾病史及残疾情况id
  int id = 0;

  /// 档案ID
  String residentHealthRecordId = '';

  /// 疾病种类ID
  int? diseaseKindId;

  /// 疾病ID
  String diseaseId = '';

  /// 状态 0 患病, 1 治愈
  String status = '';

  /// 确诊日期
  String diagnosisDate = '';

  /// 备注
  String remark = '';

  /// 确诊医生id
  String doctorId = '';

  /// 确诊医生名字
  String doctorName = '';

  /// 确诊医生电话
  String doctorTel = '';

  /// 确诊机构
  String orgId = '';

  /// 记录人id
  String userId = '';

  /// 记录人名字
  String userName = '';

  /// 慢病建档时间
  String recordDate = '';

  /// 慢病结案时间
  String statusDate = '';

  /// 确诊日期其他（1-表示不详）
  String diagnosisDateOther = '';

  PersonIllness();

  factory PersonIllness.fromJson(Map<String, dynamic> json) {
    final model = PersonIllness();
    model.id = json['id'] as int? ?? 0;
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.diseaseKindId = json['diseaseKindId'] as int?;
    model.diseaseId = _stringVal(json['diseaseId']);
    model.status = _stringVal(json['status']);
    model.diagnosisDate = _stringVal(json['diagnosisDate']);
    model.remark = _stringVal(json['remark']);
    model.doctorId = _stringVal(json['doctorId']);
    model.doctorName = _stringVal(json['doctorName']);
    model.doctorTel = _stringVal(json['doctorTel']);
    model.orgId = _stringVal(json['orgId']);
    model.userId = _stringVal(json['userId']);
    model.userName = _stringVal(json['userName']);
    model.recordDate = _stringVal(json['recordDate']);
    model.statusDate = _stringVal(json['statusDate']);
    model.diagnosisDateOther = _stringVal(json['diagnosisDateOther']);
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'residentHealthRecordId': residentHealthRecordId,
      'diseaseKindId': diseaseKindId,
      'diseaseId': diseaseId,
      'status': status,
      'diagnosisDate': diagnosisDate,
      'remark': remark,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'doctorTel': doctorTel,
      'orgId': orgId,
      'userId': userId,
      'userName': userName,
      'recordDate': recordDate,
      'statusDate': statusDate,
      'diagnosisDateOther': diagnosisDateOther,
    };
  }
}

/// 生活环境
class LivingEnvironment {
  /// 档案ID
  String residentHealthRecordId = '';

  /// 厨房排风设施 1 无, 2 油烟机, 4 换气扇,8 烟囱
  int? kitchenExhaust;

  /// 类型 1 液化气,2 煤,4 天然气,8 沼气,16 柴火,32 其他
  int? fuelType;

  /// 饮水 1 自来水, 2经净化过滤的水, 4井水, 8河湖水,16 塘水,32 其他
  int? drinkingwater;

  /// 厕所:1卫生厕所,2一格或二格粪池式,3马桶,4露天粪坑,5简易棚厕
  int? toilet;

  /// 禽畜栏 1 单设,2 室内,4 室外
  int? livestockColumn;

  LivingEnvironment();

  factory LivingEnvironment.fromJson(Map<String, dynamic> json) {
    final model = LivingEnvironment();
    model.residentHealthRecordId = _stringVal(json['residentHealthRecordId']);
    model.kitchenExhaust = json['kitchenExhaust'] as int?;
    model.fuelType = json['fuelType'] as int?;
    model.drinkingwater = json['drinkingwater'] as int?;
    model.toilet = json['toilet'] as int?;
    model.livestockColumn = json['livestockColumn'] as int?;
    return model;
  }

  Map<String, dynamic> toJson() {
    return {
      'residentHealthRecordId': residentHealthRecordId,
      'kitchenExhaust': kitchenExhaust,
      'fuelType': fuelType,
      'drinkingwater': drinkingwater,
      'toilet': toilet,
      'livestockColumn': livestockColumn,
    };
  }
}

/// 绑定的云平台账号信息
class ThirdAccountInfo {
  /// 云平台用户id
  String thirdUserId = '';

  /// 云平台用户名称
  String thirdUserName = '';

  /// 云平台用户绑定机构id
  String thirdOrgId = '';

  /// 第三方机构名称
  String thirdOrgName = '';

  ThirdAccountInfo({
    this.thirdUserId = '',
    this.thirdUserName = '',
    this.thirdOrgId = '',
    this.thirdOrgName = '',
  });
}

/// 通用安全取值
String _stringVal(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  return value.toString();
}
