/// 档案合并页面登录状态
class ArchivesMergeAuthState {
  final String token;
  final String authToken;
  final String institutionName;
  final String account;

  const ArchivesMergeAuthState({
    required this.token,
    required this.authToken,
    required this.institutionName,
    required this.account,
  });

  const ArchivesMergeAuthState.signedOut()
      : token = '',
        authToken = '',
        institutionName = '',
        account = '';

  bool get isLoggedIn => token.isNotEmpty;
}
