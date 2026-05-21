class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
}
