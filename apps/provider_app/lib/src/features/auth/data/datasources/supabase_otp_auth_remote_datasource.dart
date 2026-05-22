import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_session_model.dart';
import 'auth_remote_datasource.dart';

class SupabaseOtpAuthRemoteDataSource implements AuthRemoteDataSource {
  const SupabaseOtpAuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthSessionModel> verifyOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: otp,
      type: OtpType.sms,
    );
    return AuthSessionModel.fromSupabaseSession(
      session: response.session,
      role: role,
      phone: phone,
    );
  }
}
