import '../../domain/entities/otp_request.dart';

class OtpRequestModel extends OtpRequest {
  const OtpRequestModel({
    required super.phone,
    required super.role,
    required super.status,
    super.deliveryMethod,
    super.devOtp,
  });

  factory OtpRequestModel.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'];
    final deliveryMap =
        delivery is Map<String, dynamic> ? delivery : <String, dynamic>{};
    final provider = deliveryMap['provider'];
    final channel = deliveryMap['channel'];

    return OtpRequestModel(
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'PROVIDER',
      status: json['status'] as String? ?? 'OTP_REQUESTED',
      deliveryMethod: provider is String
          ? provider
          : channel is String
              ? channel
              : null,
      devOtp: json['devOtp'] as String?,
    );
  }
}
