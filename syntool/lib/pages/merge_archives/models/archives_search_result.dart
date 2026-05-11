import 'archives_model.dart';

/// 档案搜索列表项
class ArchivesSearchItem {
  final String id;
  final String name;
  final String idCard;
  final int? gender;
  final String birthDay;
  final String address;
  final int? ageForYear;

  ArchivesSearchItem({
    required this.id,
    required this.name,
    required this.idCard,
    this.gender,
    required this.birthDay,
    required this.address,
    this.ageForYear,
  });

  factory ArchivesSearchItem.fromJson(Map<String, dynamic> json) {
    return ArchivesSearchItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      idCard: json['idCard']?.toString() ?? '',
      gender: json['gender'] as int?,
      birthDay: json['birthDay']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      ageForYear: json['ageForYear'] as int?,
    );
  }
}

/// 档案详情包装
class ArchivesDetail {
  final String residentHealthRecordId;
  final ArchivesModel model;

  ArchivesDetail({
    required this.residentHealthRecordId,
    required this.model,
  });
}
