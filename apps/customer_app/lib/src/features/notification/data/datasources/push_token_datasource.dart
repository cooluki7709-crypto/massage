abstract class PushTokenDataSource {
  Future<DevicePushToken?> getCurrentDeviceToken();
}

class DevicePushToken {
  const DevicePushToken({
    required this.token,
    required this.platform,
  });

  final String token;
  final String platform;
}
