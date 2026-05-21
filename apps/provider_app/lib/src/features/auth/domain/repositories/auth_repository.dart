import '../entities/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> signInWithOtp({
    required String phone,
    required String otp,
    required String role,
  });
}
