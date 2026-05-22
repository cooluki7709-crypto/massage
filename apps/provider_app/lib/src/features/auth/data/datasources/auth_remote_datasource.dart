import '../models/auth_session_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthSessionModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  });
}
