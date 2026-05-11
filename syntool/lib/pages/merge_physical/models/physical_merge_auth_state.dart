class PhysicalMergeAuthState {
  final String token;
  final String authToken;
  final String institutionName;
  final String account;

  const PhysicalMergeAuthState({
    required this.token,
    required this.authToken,
    required this.institutionName,
    required this.account,
  });

  const PhysicalMergeAuthState.signedOut()
      : token = '',
        authToken = '',
        institutionName = '',
        account = '';

  bool get isLoggedIn => token.isNotEmpty;
}
