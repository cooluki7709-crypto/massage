import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'realtime_socket.dart';
export 'supabase_client_provider.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: AppConfig.apiBaseUrl);
});

final realtimeSocketProvider = Provider<RealtimeSocket>((ref) {
  final socket = RealtimeSocket(baseUrl: AppConfig.socketBaseUrl);
  ref.onDispose(socket.dispose);
  return socket;
});
