import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/providers.dart';
import 'core/realtime_socket.dart';

export 'core/providers.dart';
export 'features/auth/presentation/providers/auth_providers.dart';
export 'features/map/presentation/providers/map_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
      ref.read(apiClientProvider), ref.read(realtimeSocketProvider));
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
    final result =
        await _api.getJson('/customer/providers/nearby?lat=$lat&lng=$lng');
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
    final result =
        await _api.postJson('/customer/bookings/$bookingId/cancel', {});
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
      if (couponCode != null && couponCode.trim().isNotEmpty)
        'couponCode': couponCode.trim().toUpperCase(),
      'scheduledStartAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
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

  Future<Map<String, dynamic>> selectProvider(
      String bookingId, String providerProfileId) async {
    final result = await _api.postJson(
        '/customer/bookings/$bookingId/select-provider',
        {'providerId': providerProfileId});
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
