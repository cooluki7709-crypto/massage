import '../entities/otp_request.dart';
import '../repositories/auth_repository.dart';

class RequestOtp {
  const RequestOtp(this._repository);

  final AuthRepository _repository;

  Future<OtpRequest> call({
    required String phone,
    required String role,
  }) {
    return _repository.requestOtp(phone: phone, role: role);
  }
}
