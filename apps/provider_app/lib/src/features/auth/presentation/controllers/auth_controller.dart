import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/usecases/sign_in_with_otp.dart';

class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._signInWithOtp) : super(null);

  final SignInWithOtp _signInWithOtp;

  Future<void> signInDemoProvider() async {
    state = await _signInWithOtp(
      phone: '+84900000002',
      otp: '123456',
      role: 'PROVIDER',
    );
  }
}
