import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/provider_device_location_datasource.dart';

final providerDeviceLocationDataSourceProvider =
    Provider<ProviderDeviceLocationDataSource>((ref) {
  return ProviderDeviceLocationDataSource();
});
