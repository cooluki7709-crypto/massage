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

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.user,
  });

  final String userId;
  final String accessToken;
  final Map<String, dynamic> user;
}

class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._api, this._socket) : super(null);

  final ApiClient _api;
  final RealtimeSocket _socket;

  Future<void> signInDemoProvider() async {
    final result = await _api.postJson('/auth/verify-otp', {
      'phone': '+84900000002',
      'otp': '123456',
      'role': 'PROVIDER',
    }) as Map<String, dynamic>;
    final accessToken = result['accessToken'] as String;
    final user = result['user'] as Map<String, dynamic>;
    _api.accessToken = accessToken;
    _socket.connect(accessToken);
    state = AuthSession(userId: user['id'] as String, accessToken: accessToken, user: user);
  }
}

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(ref.read(apiClientProvider), ref.read(realtimeSocketProvider));
});

class ProviderRepository {
  ProviderRepository(this._api, this._socket);

  final ApiClient _api;
  final RealtimeSocket _socket;

  Future<void> goOnline() async {
    await _api.postJson('/provider/online', {});
    await updateLocation();
  }

  Future<void> goOffline() async {
    await _api.postJson('/provider/offline', {});
  }

  Future<void> updateLocation({String? bookingId}) async {
    await _api.postJson('/provider/location', {'lat': 10.7769, 'lng': 106.7009});
    _socket.updateLocation(lat: 10.7769, lng: 106.7009, bookingId: bookingId);
  }

  Future<List<dynamic>> openBookings() async {
    final result = await _api.getJson('/provider/bookings/open');
    return result is List<dynamic> ? result : [];
  }

  Future<Map<String, dynamic>> joinBooking(String bookingId) async {
    final result = await _api.postJson('/provider/bookings/$bookingId/join', {}) as Map<String, dynamic>;
    _socket.joinBooking(bookingId);
    return result;
  }

  Future<Map<String, dynamic>> acceptBooking(String bookingId) async {
    final result = await _api.postJson('/provider/bookings/$bookingId/accept', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    final result = await _api.postJson('/provider/bookings/$bookingId/reject', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<void> registerPushToken(String token) async {
    await _api.postJson('/notifications/device-token/register', {
      'token': token,
      'platform': 'android',
    });
  }

  Future<Map<String, dynamic>> earningsSummary() async {
    final result = await _api.getJson('/provider/earnings/summary');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<List<dynamic>> earnings() async {
    final result = await _api.getJson('/provider/earnings');
    return result is List<dynamic> ? result : [];
  }

  Future<List<dynamic>> payoutBatches() async {
    final result = await _api.getJson('/provider/earnings/payout-batches');
    return result is List<dynamic> ? result : [];
  }

  Future<Map<String, dynamic>> verification() async {
    final result = await _api.getJson('/provider/verification');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createVerificationUpload({String contentType = 'image/jpeg'}) async {
    final result = await _api.postJson('/files/presign', {
      'contentType': contentType,
      'visibility': 'PRIVATE',
      'purpose': 'provider-verification',
    });
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitVerification({List<String> fileIds = const []}) async {
    final result = await _api.postJson('/provider/verification/submit', {'fileIds': fileIds});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}
