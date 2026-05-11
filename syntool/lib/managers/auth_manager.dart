import '../models/institution_info.dart';

class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  factory AuthManager() => _instance;
  AuthManager._internal();

  InstitutionInfo? _institutionInfo;

  InstitutionInfo? get institutionInfo => _institutionInfo;
  bool get isLoggedIn => _institutionInfo != null;

  void setInstitutionInfo(InstitutionInfo info) {
    _institutionInfo = info;
  }

  void logout() {
    _institutionInfo = null;
  }
}