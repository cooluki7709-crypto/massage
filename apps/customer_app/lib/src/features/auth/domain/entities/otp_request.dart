class OtpRequest {
  const OtpRequest({
    required this.phone,
    required this.role,
    required this.status,
    this.deliveryMethod,
    this.devOtp,
  });

  final String phone;
  final String role;
  final String status;
  final String? deliveryMethod;
  final String? devOtp;
}
