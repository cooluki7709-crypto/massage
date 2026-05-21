import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../data/repositories/customer_coupon_repository_impl.dart';
import '../../domain/repositories/customer_coupon_repository.dart';

final customerCouponRepositoryProvider =
    Provider<CustomerCouponRepository>((ref) {
  return CustomerCouponRepositoryImpl(ref.read(apiClientProvider));
});
