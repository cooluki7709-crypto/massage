import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/usecases/request_otp.dart';
import '../../domain/usecases/sign_in_with_otp.dart';

class AuthController extends StateNotifier<AuthSession?> {
  AuthController({
    required RequestOtp requestOtp,
    required SignInWithOtp signInWithOtp,
  })  : _requestOtp = requestOtp,
        _signInWithOtp = signInWithOtp,
        super(null);

  final RequestOtp _requestOtp;
  final SignInWithOtp _signInWithOtp;

  Future<OtpRequest> requestOtp({
    required String phone,
    String role = 'CUSTOMER',
  }) {
    return _requestOtp(phone: phone, role: role);
  }

  Future<OtpRequest> requestDemoCustomerOtp() {
    return requestOtp(phone: '+84900000001');
  }

  Future<void> signInWithOtp({
    required String phone,
    required String otp,
    String role = 'CUSTOMER',
  }) async {
    state = await _signInWithOtp(phone: phone, otp: otp, role: role);
  }

  Future<void> signInDemoCustomer() async {
    await signInWithOtp(
      phone: '+84900000001',
      otp: '123456',
    );
  }
}
