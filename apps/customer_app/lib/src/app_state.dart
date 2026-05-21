import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/providers.dart';
import 'features/booking/domain/repositories/customer_booking_repository.dart';
import 'features/booking/presentation/providers/booking_providers.dart';
import 'features/chat/domain/repositories/chat_repository.dart';
import 'features/chat/presentation/providers/chat_providers.dart';
import 'features/discovery/domain/repositories/customer_discovery_repository.dart';
import 'features/discovery/presentation/providers/discovery_providers.dart';
import 'features/notification/domain/repositories/push_notification_repository.dart';
import 'features/notification/presentation/providers/notification_providers.dart';

export 'core/providers.dart';
export 'features/auth/presentation/providers/auth_providers.dart';
export 'features/booking/presentation/providers/booking_providers.dart';
export 'features/chat/presentation/providers/chat_providers.dart';
export 'features/discovery/presentation/providers/discovery_providers.dart';
export 'features/map/presentation/providers/map_providers.dart';
export 'features/notification/presentation/providers/notification_providers.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(
    ref.read(apiClientProvider),
    ref.read(customerDiscoveryRepositoryProvider),
    ref.read(customerBookingRepositoryProvider),
    ref.read(chatRepositoryProvider),
    ref.read(pushNotificationRepositoryProvider),
  );
});

class CustomerRepository {
  CustomerRepository(
      this._api,
      this._discoveryRepository,
      this._bookingRepository,
      this._chatRepository,
      this._notificationRepository);

  final ApiClient _api;
  final CustomerDiscoveryRepository _discoveryRepository;
  final CustomerBookingRepository _bookingRepository;
  final ChatRepository _chatRepository;
  final PushNotificationRepository _notificationRepository;

  Future<List<dynamic>> listServices() async {
    return _discoveryRepository.listServices();
  }

  Future<List<dynamic>> nearbyProviders({
    required double lat,
    required double lng,
  }) async {
    return _discoveryRepository.nearbyProviders(lat: lat, lng: lng);
  }

  Future<void> saveSelectedLocation({
    required double lat,
    required double lng,
    required String addressText,
  }) async {
    await _discoveryRepository.saveSelectedLocation(
      lat: lat,
      lng: lng,
      addressText: addressText,
    );
  }

  Future<Map<String, dynamic>> getProviderDetail(String providerId) async {
    return _discoveryRepository.getProviderDetail(providerId);
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
    await _notificationRepository.registerDeviceToken(token: token);
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
