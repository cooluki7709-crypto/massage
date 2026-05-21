import '../entities/push_token_registration_result.dart';

abstract class PushNotificationRepository {
  Future<PushTokenRegistrationResult> registerCurrentDevice();

  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
  });
}
