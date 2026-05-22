import '../entities/auth_session.dart';
import '../entities/otp_request.dart';

abstract class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<OtpRequest> requestOtp({
    required String phone,
    required String role,
  });

  Future<AuthSession> signInWithOtp({
    required String phone,
    required String otp,
    required String role,
  });
}
