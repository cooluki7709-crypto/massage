import '../../domain/entities/push_token_registration_result.dart';
import '../../domain/repositories/push_notification_repository.dart';
import '../datasources/notification_remote_datasource.dart';
import '../datasources/push_token_datasource.dart';

class PushNotificationRepositoryImpl implements PushNotificationRepository {
  const PushNotificationRepositoryImpl({
    required PushTokenDataSource pushTokenDataSource,
    required NotificationRemoteDataSource remoteDataSource,
  })  : _pushTokenDataSource = pushTokenDataSource,
        _remoteDataSource = remoteDataSource;

  final PushTokenDataSource _pushTokenDataSource;
  final NotificationRemoteDataSource _remoteDataSource;

  @override
  Future<PushTokenRegistrationResult> registerCurrentDevice() async {
    try {
      final deviceToken = await _pushTokenDataSource.getCurrentDeviceToken();
      if (deviceToken == null) {
        return const PushTokenRegistrationResult(
          registered: false,
          message: 'Push token not available on this device yet.',
        );
      }

      await _remoteDataSource.registerDeviceToken(
        token: deviceToken.token,
        platform: deviceToken.platform,
      );
      return const PushTokenRegistrationResult(
          registered: true, message: 'Push token registered.');
    } catch (exception) {
      return PushTokenRegistrationResult(
        registered: false,
        message: 'Push setup pending: $exception',
      );
    }
  }

  @override
  Future<void> registerDeviceToken({
    required String token,
    String platform = 'android',
  }) async {
    await _remoteDataSource.registerDeviceToken(
      token: token,
      platform: platform,
    );
  }
}
