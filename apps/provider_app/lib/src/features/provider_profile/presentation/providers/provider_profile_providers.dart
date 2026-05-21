import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../map/presentation/providers/map_providers.dart';
import '../../data/repositories/provider_profile_repository_impl.dart';
import '../../domain/repositories/provider_profile_repository.dart';

final providerProfileRepositoryProvider =
    Provider<ProviderProfileRepository>((ref) {
  return ProviderProfileRepositoryImpl(
    api: ref.read(apiClientProvider),
    socket: ref.read(realtimeSocketProvider),
    locationDataSource: ref.read(providerDeviceLocationDataSourceProvider),
  );
});
