import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/restore_auth_session.dart';
import '../../domain/usecases/sign_in_with_otp.dart';

class AuthController extends StateNotifier<AuthSession?> {
  AuthController({
    required RestoreAuthSession restoreAuthSession,
    required RequestOtp requestOtp,
    required SignInWithOtp signInWithOtp,
  })  : _restoreAuthSession = restoreAuthSession,
        _requestOtp = requestOtp,
        _signInWithOtp = signInWithOtp,
        super(null);

  final RestoreAuthSession _restoreAuthSession;
  final RequestOtp _requestOtp;
  final SignInWithOtp _signInWithOtp;

  Future<AuthSession?> restoreSession() async {
    if (state != null) {
      return state;
    }
    final session = await _restoreAuthSession();
    state = session;
    return session;
  }

  Future<OtpRequest> requestOtp({
    required String phone,
    String role = 'PROVIDER',
  }) {
    return _requestOtp(phone: phone, role: role);
  }

  Future<OtpRequest> requestDemoProviderOtp() {
    return requestOtp(phone: '+84900000002');
  }

  Future<void> signInWithOtp({
    required String phone,
    required String otp,
    String role = 'PROVIDER',
  }) async {
    state = await _signInWithOtp(phone: phone, otp: otp, role: role);
  }

  Future<void> signInDemoProvider() async {
    await signInWithOtp(
      phone: '+84900000002',
      otp: '123456',
    );
  }
}
