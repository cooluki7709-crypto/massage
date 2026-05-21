import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/repositories/provider_earnings_repository_impl.dart';
import '../../domain/repositories/provider_earnings_repository.dart';

final providerEarningsRepositoryProvider =
    Provider<ProviderEarningsRepository>((ref) {
  return ProviderEarningsRepositoryImpl(ref.read(apiClientProvider));
});
