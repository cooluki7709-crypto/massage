import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_config.dart';
import '../../../../core/providers.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/nest_otp_auth_remote_datasource.dart';
import '../../data/datasources/supabase_otp_auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_with_otp.dart';
import '../controllers/auth_controller.dart';

export '../../domain/entities/auth_session.dart';
export '../controllers/auth_controller.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  if (AppConfig.authBackend == AuthBackend.supabase) {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      throw StateError(
        'AUTH_BACKEND=supabase requires SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return SupabaseOtpAuthRemoteDataSource(client);
  }

  return NestOtpAuthRemoteDataSource(ref.read(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.read(authRemoteDataSourceProvider),
    apiClient: ref.read(apiClientProvider),
    realtimeSocket: ref.read(realtimeSocketProvider),
  );
});

final signInWithOtpProvider = Provider<SignInWithOtp>((ref) {
  return SignInWithOtp(ref.read(authRepositoryProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(ref.read(signInWithOtpProvider));
});
