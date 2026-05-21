import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/repositories/provider_verification_repository_impl.dart';
import '../../domain/repositories/provider_verification_repository.dart';

final providerVerificationRepositoryProvider =
    Provider<ProviderVerificationRepository>((ref) {
  return ProviderVerificationRepositoryImpl(ref.read(apiClientProvider));
});
