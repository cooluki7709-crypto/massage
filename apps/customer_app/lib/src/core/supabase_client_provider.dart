import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.supabaseEnabled) {
    return null;
  }

  return SupabaseClient(
    AppConfig.supabaseUrl,
    AppConfig.supabaseAnonKey,
  );
});
