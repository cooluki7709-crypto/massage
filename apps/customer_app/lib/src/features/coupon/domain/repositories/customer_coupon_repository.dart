abstract class CustomerCouponRepository {
  Future<Map<String, dynamic>> previewCoupon({
    required String code,
    required String serviceId,
    required int subtotal,
  });
}
