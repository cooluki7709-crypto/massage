import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

class SignInWithOtp {
  const SignInWithOtp(this._repository);

  final AuthRepository _repository;

  Future<AuthSession> call({
    required String phone,
    required String otp,
    required String role,
  }) {
    return _repository.signInWithOtp(phone: phone, otp: otp, role: role);
  }
}
