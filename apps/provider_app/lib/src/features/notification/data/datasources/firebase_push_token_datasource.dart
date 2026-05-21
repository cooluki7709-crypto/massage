import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_token_datasource.dart';

class FirebasePushTokenDataSource implements PushTokenDataSource {
  @override
  Future<DevicePushToken?> getCurrentDeviceToken() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    return DevicePushToken(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
    );
  }
}
