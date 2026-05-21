import '../../../../core/api_client.dart';
import '../../domain/repositories/customer_discovery_repository.dart';

class CustomerDiscoveryRepositoryImpl implements CustomerDiscoveryRepository {
  const CustomerDiscoveryRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<dynamic>> listServices() async {
    final result = await _api.getJson('/services');
    return result is List<dynamic> ? result : [];
  }

  @override
  Future<List<dynamic>> nearbyProviders({
    required double lat,
    required double lng,
  }) async {
    final result =
        await _api.getJson('/customer/providers/nearby?lat=$lat&lng=$lng');
    return result is List<dynamic> ? result : [];
  }

  @override
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

  @override
  Future<Map<String, dynamic>> getProviderDetail(String providerId) async {
    final result = await _api.getJson('/customer/providers/$providerId');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}
