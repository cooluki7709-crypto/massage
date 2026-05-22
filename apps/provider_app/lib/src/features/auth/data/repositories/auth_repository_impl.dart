import '../../../../core/api_client.dart';
import '../../../../core/realtime_socket.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required ApiClient apiClient,
    required RealtimeSocket realtimeSocket,
  })  : _remoteDataSource = remoteDataSource,
        _apiClient = apiClient,
        _realtimeSocket = realtimeSocket;

  final AuthRemoteDataSource _remoteDataSource;
  final ApiClient _apiClient;
  final RealtimeSocket _realtimeSocket;

  @override
  Future<AuthSession> signInWithOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final session =
        await _remoteDataSource.verifyOtp(phone: phone, otp: otp, role: role);
    _apiClient.accessToken = session.accessToken;
    _apiClient.refreshToken = session.refreshToken;
    _realtimeSocket.connect(session.accessToken);
    return session;
  }
}
