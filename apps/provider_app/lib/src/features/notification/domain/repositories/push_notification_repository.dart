import '../entities/push_token_registration_result.dart';

abstract class PushNotificationRepository {
  Future<PushTokenRegistrationResult> registerCurrentDevice();
}
