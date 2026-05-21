import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'core/api_client.dart';
import 'core/providers.dart';
import 'core/realtime_socket.dart';
import 'features/map/data/datasources/provider_device_location_datasource.dart';
import 'features/map/domain/services/provider_location_heartbeat.dart';
import 'features/map/presentation/providers/map_providers.dart';

export 'core/providers.dart';
export 'features/auth/presentation/providers/auth_providers.dart';
export 'features/map/presentation/providers/map_providers.dart';

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(
    ref.read(apiClientProvider),
    ref.read(realtimeSocketProvider),
    ref.read(providerDeviceLocationDataSourceProvider),
  );
});

final providerLocationHeartbeatProvider =
    Provider<ProviderLocationHeartbeat>((ref) {
  final heartbeat = ProviderLocationHeartbeat(() async {
    await ref.read(providerRepositoryProvider).updateLocation();
  });
  ref.onDispose(heartbeat.dispose);
  return heartbeat;
});

const double demoProviderLat = 10.7769;
const double demoProviderLng = 106.7009;

class ProviderRepository {
  ProviderRepository(this._api, this._socket, this._locationDataSource);

  final ApiClient _api;
  final RealtimeSocket _socket;
  final ProviderDeviceLocationDataSource _locationDataSource;

  Future<void> goOnline() async {
    await _api.postJson('/provider/online', {});
    await updateLocation();
  }

  Future<void> goOffline() async {
    await _api.postJson('/provider/offline', {});
  }

  Future<Map<String, double>> updateLocation({String? bookingId}) async {
    final position = await _locationDataSource.currentPosition();
    final resolved = await resolveProviderLocation(position);
    final lat = resolved['lat']!;
    final lng = resolved['lng']!;
    await _api.postJson('/provider/location', {'lat': lat, 'lng': lng});
    _socket.updateLocation(lat: lat, lng: lng, bookingId: bookingId);
    return {'lat': lat, 'lng': lng};
  }

  Future<Map<String, double>> resolveProviderLocation(
      Position? position) async {
    final lat = position?.latitude;
    final lng = position?.longitude;
    if (lat != null && lng != null && isVietnamCoordinate(lat, lng)) {
      return {'lat': lat, 'lng': lng};
    }

    final me = await providerMe();
    final profile = me['providerProfile'] as Map<String, dynamic>?;
    final profileLat = asNum(profile?['currentLat'])?.toDouble();
    final profileLng = asNum(profile?['currentLng'])?.toDouble();
    if (profileLat != null &&
        profileLng != null &&
        isVietnamCoordinate(profileLat, profileLng)) {
      return {'lat': profileLat, 'lng': profileLng};
    }

    return {'lat': demoProviderLat, 'lng': demoProviderLng};
  }

  Future<Map<String, dynamic>> providerMe() async {
    final result = await _api.getJson('/provider/me');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<List<dynamic>> openBookings() async {
    final result = await _api.getJson('/provider/bookings/open');
    return result is List<dynamic> ? result : [];
  }

  Future<List<dynamic>> listBookings() async {
    final result = await _api.getJson('/provider/bookings');
    return result is List<dynamic> ? result : [];
  }

  Future<List<dynamic>> requestBookings() async {
    final openItems = await openBookings();
    final ownItems = await listBookings();
    final merged = <String, Map<String, dynamic>>{};

    for (final item in [...openItems, ...ownItems]) {
      if (item is Map<String, dynamic>) {
        final id = item['id'] as String?;
        if (id != null) {
          merged[id] = item;
        }
      }
    }

    const activeStatuses = {
      'OPEN_MATCHING',
      'MATCHED',
      'PROVIDER_ON_THE_WAY',
      'ARRIVED',
      'IN_SERVICE',
    };
    return merged.values
        .where((booking) => activeStatuses.contains(booking['status']))
        .toList()
      ..sort((left, right) {
        final leftValue =
            (left['openedAt'] ?? left['createdAt'] ?? '') as String;
        final rightValue =
            (right['openedAt'] ?? right['createdAt'] ?? '') as String;
        return rightValue.compareTo(leftValue);
      });
  }

  Future<Map<String, dynamic>> joinBooking(String bookingId) async {
    final result = await _api.postJson('/provider/bookings/$bookingId/join', {})
        as Map<String, dynamic>;
    _socket.joinBooking(bookingId);
    return result;
  }

  Future<Map<String, dynamic>> acceptBooking(String bookingId) async {
    final result =
        await _api.postJson('/provider/bookings/$bookingId/accept', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> rejectBooking(String bookingId) async {
    final result =
        await _api.postJson('/provider/bookings/$bookingId/reject', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> startBooking(String bookingId) async {
    final result =
        await _api.postJson('/provider/bookings/$bookingId/start', {});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
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

  Future<Map<String, dynamic>> createVerificationUpload(
      {String contentType = 'image/jpeg'}) async {
    final result = await _api.postJson('/files/presign', {
      'contentType': contentType,
      'visibility': 'PRIVATE',
      'purpose': 'provider-verification',
    });
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitVerification(
      {List<String> fileIds = const []}) async {
    final result = await _api
        .postJson('/provider/verification/submit', {'fileIds': fileIds});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}

bool isVietnamCoordinate(double lat, double lng) {
  return lat >= 8.0 && lat <= 24.0 && lng >= 102.0 && lng <= 110.0;
}

num? asNum(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}
