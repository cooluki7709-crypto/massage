import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/providers.dart';
import 'features/booking/domain/repositories/customer_booking_repository.dart';
import 'features/booking/presentation/providers/booking_providers.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/presentation/providers/chat_providers.dart';

export 'core/providers.dart';
export 'features/auth/presentation/providers/auth_providers.dart';
export 'features/booking/presentation/providers/booking_providers.dart';
export 'features/chat/presentation/providers/chat_providers.dart';
export 'features/map/presentation/providers/map_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    ref.read(apiClientProvider),
    ref.read(customerBookingRepositoryProvider),
    ref.read(chatRepositoryProvider),
  );
});

class CustomerRepository {
  CustomerRepository(this._api, this._bookingRepository, this._chatRepository);

  final ApiClient _api;
  final CustomerBookingRepository _bookingRepository;
  final ChatRepository _chatRepository;

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
    return _bookingRepository.getBooking(bookingId);
  }

  Future<List<dynamic>> listBookings() async {
    return _bookingRepository.listBookings();
  }

  void joinBookingRoom(String bookingId) {
    _bookingRepository.joinBookingRoom(bookingId);
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    return _bookingRepository.cancelBooking(bookingId);
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
    return _bookingRepository.createBooking(
      serviceId,
      providerId: providerId,
      couponCode: couponCode,
      customerName: customerName,
      customerPhone: customerPhone,
      addressLine: addressLine,
      lat: lat,
      lng: lng,
    );
  }

  Future<Map<String, dynamic>> selectProvider(
      String bookingId, String providerProfileId) async {
    return _bookingRepository.selectProvider(bookingId, providerProfileId);
  }

  Future<List<dynamic>> listChatMessages(String chatRoomId) async {
    return _chatRepository.listChatMessages(chatRoomId);
  }

  void joinChat(String chatRoomId) {
    _chatRepository.joinChat(chatRoomId);
  }

  void sendChatMessage(String chatRoomId, String text) {
    _chatRepository.sendChatMessage(chatRoomId, text);
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
