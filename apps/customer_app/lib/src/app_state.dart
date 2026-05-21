import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/realtime_socket.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConfig.apiBaseUrl);
});

final realtimeSocketProvider = Provider<RealtimeSocket>((ref) {
  final socket = RealtimeSocket(baseUrl: AppConfig.socketBaseUrl);
  ref.onDispose(socket.dispose);
  return socket;
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(ref.read(apiClientProvider), ref.read(realtimeSocketProvider));
});

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  return PushTokenRegistrar(ref.read(apiClientProvider));
});

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
}

class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._api, this._socket) : super(null);

  final ApiClient _api;
  final RealtimeSocket _socket;

  Future<void> signInDemoCustomer() async {
    final result = await _api.postJson('/auth/verify-otp', {
      'phone': '+84900000001',
      'otp': '123456',
      'role': 'CUSTOMER',
    });
    final accessToken = result['accessToken'] as String;
    final refreshToken = result['refreshToken'] as String;
    final user = result['user'] as Map<String, dynamic>;
    _api.accessToken = accessToken;
    _api.refreshToken = refreshToken;
    _socket.connect(accessToken);
    state = AuthSession(
      userId: user['id'] as String,
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.read(apiClientProvider), ref.read(realtimeSocketProvider));
});

class CustomerRepository {
  CustomerRepository(this._api, this._socket);

  final ApiClient _api;
  final RealtimeSocket _socket;

  Future<List<dynamic>> listServices() async {
    final result = await _api.getJson('/services');
    return result is List<dynamic> ? result : [];
  }

  Future<List<dynamic>> nearbyProviders() async {
    final result = await _api.getJson('/customer/providers/nearby?lat=10.7769&lng=106.7009');
    return result is List<dynamic> ? result : [];
  }

  Future<Map<String, dynamic>> getProviderDetail(String providerId) async {
    final result = await _api.getJson('/customer/providers/$providerId');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBooking(String bookingId) async {
    final result = await _api.getJson('/customer/bookings/$bookingId');
    return result as Map<String, dynamic>;
  }

  Future<List<dynamic>> listBookings() async {
    final result = await _api.getJson('/customer/bookings');
    return result is List<dynamic> ? result : [];
  }

  void joinBookingRoom(String bookingId) {
    _socket.joinBooking(bookingId);
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    final result = await _api.postJson('/customer/bookings/$bookingId/cancel', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createBooking(
    String serviceId, {
    String? providerId,
    required String customerName,
    required String customerPhone,
    required String addressLine,
    required double lat,
    required double lng,
  }) async {
    final result = await _api.postJson('/customer/bookings', {
      'serviceId': serviceId,
      if (providerId != null) 'providerId': providerId,
      'scheduledStartAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'address': {
        'name': customerName,
        'phone': customerPhone,
        'line1': addressLine,
      },
      'lat': lat,
      'lng': lng,
      'paymentMethod': 'CASH',
    });
    final bookingId = result['id'] as String;
    _socket.joinBooking(bookingId);
    return getBooking(bookingId);
  }

  Future<Map<String, dynamic>> selectProvider(String bookingId, String providerProfileId) async {
    final result = await _api.postJson('/customer/bookings/$bookingId/select-provider', {'providerId': providerProfileId});
    return result as Map<String, dynamic>;
  }

  Future<List<dynamic>> listChatMessages(String chatRoomId) async {
    final result = await _api.getJson('/chat/rooms/$chatRoomId/messages');
    return result is List<dynamic> ? result : [];
  }

  void joinChat(String chatRoomId) {
    _socket.joinChat(chatRoomId);
  }

  void sendChatMessage(String chatRoomId, String text) {
    _socket.sendChatMessage(chatRoomId, text);
  }

  Future<void> registerPushToken(String token) async {
    await _api.postJson('/notifications/device-token/register', {
      'token': token,
      'platform': 'android',
    });
  }
}

class PushTokenRegistrationResult {
  const PushTokenRegistrationResult({required this.registered, required this.message});

  final bool registered;
  final String message;
}

class PushTokenRegistrar {
  PushTokenRegistrar(this._api);

  final ApiClient _api;

  Future<PushTokenRegistrationResult> registerCurrentDevice() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return const PushTokenRegistrationResult(
          registered: false,
          message: 'Push token not available on this device yet.',
        );
      }

      await _api.postJson('/notifications/device-token/register', {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      return const PushTokenRegistrationResult(registered: true, message: 'Push token registered.');
    } catch (exception) {
      return PushTokenRegistrationResult(
        registered: false,
        message: 'Push setup pending: $exception',
      );
    }
  }
}
