abstract class ProviderVerificationRepository {
  Future<Map<String, dynamic>> verification();

  Future<Map<String, dynamic>> createVerificationUpload({
    String contentType = 'image/jpeg',
  });

  Future<Map<String, dynamic>> submitVerification({
    List<String> fileIds = const [],
  });
}
