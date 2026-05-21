import '../entities/push_token_registration_result.dart';
import '../repositories/push_notification_repository.dart';

class RegisterCurrentDevicePushToken {
  const RegisterCurrentDevicePushToken(this._repository);

  final PushNotificationRepository _repository;

  Future<PushTokenRegistrationResult> call() {
    return _repository.registerCurrentDevice();
  }
}
