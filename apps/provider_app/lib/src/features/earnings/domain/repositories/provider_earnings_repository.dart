abstract class ProviderEarningsRepository {
  Future<Map<String, dynamic>> earningsSummary();

  Future<List<dynamic>> earnings();

  Future<List<dynamic>> payoutBatches();
}
