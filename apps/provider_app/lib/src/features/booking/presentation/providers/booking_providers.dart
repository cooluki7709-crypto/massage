import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/repositories/provider_booking_repository_impl.dart';
import '../../domain/repositories/provider_booking_repository.dart';

final providerBookingRepositoryProvider =
    Provider<ProviderBookingRepository>((ref) {
  return ProviderBookingRepositoryImpl(
    ref.read(apiClientProvider),
    ref.read(realtimeSocketProvider),
  );
});
