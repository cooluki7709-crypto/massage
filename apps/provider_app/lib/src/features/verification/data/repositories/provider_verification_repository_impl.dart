import '../../../../core/api_client.dart';
import '../../domain/repositories/provider_verification_repository.dart';

class ProviderVerificationRepositoryImpl
    implements ProviderVerificationRepository {
  const ProviderVerificationRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Map<String, dynamic>> verification() async {
    final result = await _api.getJson('/provider/verification');
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> createVerificationUpload({
    String contentType = 'image/jpeg',
  }) async {
    final result = await _api.postJson('/files/presign', {
      'contentType': contentType,
      'visibility': 'PRIVATE',
      'purpose': 'provider-verification',
    });
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> submitVerification({
    List<String> fileIds = const [],
  }) async {
    final result = await _api
        .postJson('/provider/verification/submit', {'fileIds': fileIds});
    return result is Map<String, dynamic> ? result : <String, dynamic>{};
  }
}
