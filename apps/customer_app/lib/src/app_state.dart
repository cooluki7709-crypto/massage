import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/providers.dart';
import 'core/realtime_socket.dart';

export 'core/providers.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(ref.read(apiClientProvider), ref.read(realtimeSocketProvider));
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

final geoapifySearchProvider = Provider<GeoapifySearchService>((ref) {
  return GeoapifySearchService(apiKey: AppConfig.geoapifyApiKey);
});

class CustomerRepository {
  CustomerRepository(this._api, this._socket);

  final ApiClient _api;
  final RealtimeSocket _socket;

  Future<List<dynamic>> listServices() async {
    final result = await _api.getJson('/services');
    return result is List<dynamic> ? result : [];
  }

  Future<List<dynamic>> nearbyProviders({
    required double lat,
    required double lng,
  }) async {
    final result = await _api.getJson('/customer/providers/nearby?lat=$lat&lng=$lng');
    return result is List<dynamic> ? result : [];
  }

  Future<void> saveSelectedLocation({
    required double lat,
    required double lng,
    required String addressText,
  }) async {
    await _api.postJson('/customer/locations/selected', {
      'lat': lat,
      'lng': lng,
      'addressText': addressText,
    });
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
    String? couponCode,
    required String customerName,
    required String customerPhone,
    required String addressLine,
    required double lat,
    required double lng,
  }) async {
    final result = await _api.postJson('/customer/bookings', {
      'serviceId': serviceId,
      if (providerId != null) 'providerId': providerId,
      if (couponCode != null && couponCode.trim().isNotEmpty) 'couponCode': couponCode.trim().toUpperCase(),
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

  Future<Map<String, dynamic>> previewCoupon({
    required String code,
    required String serviceId,
    required int subtotal,
  }) async {
    final result = await _api.postJson('/customer/coupons/preview', {
      'code': code.trim().toUpperCase(),
      'serviceId': serviceId,
      'subtotal': subtotal,
    });
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}

class AddressSearchResult {
  const AddressSearchResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;
}

class GeoapifySearchService {
  GeoapifySearchService({required this.apiKey});

  final String apiKey;
  final Map<String, List<AddressSearchResult>> _cache = {};

  Future<List<AddressSearchResult>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2 || apiKey.isEmpty) {
      return [];
    }
    final cached = _cache[normalized];
    if (cached != null) {
      return cached;
    }

    final uri = Uri.https('api.geoapify.com', '/v1/geocode/search', {
      'text': query.trim(),
      'filter': 'countrycode:vn',
      'bias': 'countrycode:vn',
      'lang': 'vi',
      'limit': '6',
      'apiKey': apiKey,
    });
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Address search failed (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final features = body['features'] is List<dynamic> ? body['features'] as List<dynamic> : [];
    final results = features
        .map((feature) {
          final item = feature as Map<String, dynamic>;
          final properties = item['properties'] as Map<String, dynamic>? ?? {};
          final lat = asDouble(properties['lat']);
          final lng = asDouble(properties['lon']);
          final label = properties['formatted']?.toString() ?? properties['address_line1']?.toString() ?? query;
          if (lat == null || lng == null) {
            return null;
          }
          return AddressSearchResult(label: label, latitude: lat, longitude: lng);
        })
        .whereType<AddressSearchResult>()
        .toList();
    _cache[normalized] = results;
    return results;
  }
}

final customerLocationProvider = Provider<CustomerLocationService>((ref) {
  return CustomerLocationService();
});

class CustomerLocationService {
  Future<Position?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}

double? asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
