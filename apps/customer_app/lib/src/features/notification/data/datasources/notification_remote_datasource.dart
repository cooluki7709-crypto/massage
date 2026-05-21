import '../../../../core/api_client.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource(this._api);

  final ApiClient _api;

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _api.postJson('/notifications/device-token/register', {
      'token': token,
      'platform': platform,
    });
  }
}
