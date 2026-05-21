import '../../../../core/api_client.dart';
import '../../domain/repositories/customer_coupon_repository.dart';

class CustomerCouponRepositoryImpl implements CustomerCouponRepository {
  const CustomerCouponRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> previewCoupon({
    required String code,
    required String serviceId,
    required int subtotal,
  }) async {
    final result = await _api.postJson('/customer/coupons/preview', {
      'code': code.trim().toUpperCase(),
      'serviceId': serviceId,
      'subtotal': subtotal,
    });
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}
