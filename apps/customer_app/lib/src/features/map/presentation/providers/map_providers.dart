import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_config.dart';
import '../../data/datasources/customer_device_location_datasource.dart';
import '../../data/datasources/geoapify_geocoding_datasource.dart';

export '../../domain/entities/address_search_result.dart';

final geoapifySearchProvider = Provider<GeoapifyGeocodingDataSource>((ref) {
  return GeoapifyGeocodingDataSource(apiKey: AppConfig.geoapifyApiKey);
});

final customerLocationProvider =
    Provider<CustomerDeviceLocationDataSource>((ref) {
  return CustomerDeviceLocationDataSource();
});
