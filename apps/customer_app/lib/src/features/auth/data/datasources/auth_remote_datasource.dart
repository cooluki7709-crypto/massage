import '../../../../core/api_client.dart';
import '../models/auth_session_model.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiClient _api;

  Future<AuthSessionModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final result = await _api.postJson('/auth/verify-otp', {
      'phone': phone,
      'otp': otp,
      'role': role,
    });
    return AuthSessionModel.fromJson(result as Map<String, dynamic>);
  }
}
