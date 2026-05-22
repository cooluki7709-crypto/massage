import '../models/auth_session_model.dart';
import '../models/otp_request_model.dart';

abstract class AuthRemoteDataSource {
  Future<OtpRequestModel> requestOtp({
    required String phone,
    required String role,
  });

  Future<AuthSessionModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  });
}
