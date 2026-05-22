import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/api_client.dart';
import '../models/auth_session_model.dart';
import 'auth_remote_datasource.dart';

class SupabaseOtpAuthRemoteDataSource implements AuthRemoteDataSource {
  const SupabaseOtpAuthRemoteDataSource(this._client, this._api);

  final SupabaseClient _client;
  final ApiClient _api;

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
    final supabaseSession = AuthSessionModel.fromSupabaseSession(
      session: response.session,
      role: role,
      phone: phone,
    );
    final exchanged = await _api.postJson('/auth/supabase/exchange', {
      'supabaseAccessToken': supabaseSession.accessToken,
      'role': role,
    });
    return AuthSessionModel.fromJson(exchanged as Map<String, dynamic>);
  }
}
