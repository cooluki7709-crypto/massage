abstract class CustomerDiscoveryRepository {
  Future<List<dynamic>> listServices();

  Future<List<dynamic>> nearbyProviders({
    required double lat,
    required double lng,
  });

  Future<void> saveSelectedLocation({
    required double lat,
    required double lng,
    required String addressText,
  });

  Future<Map<String, dynamic>> getProviderDetail(String providerId);
}
