import '../../../../core/api_client.dart';
import '../../../../core/realtime_socket.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/otp_request.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required ApiClient apiClient,
    required RealtimeSocket realtimeSocket,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _apiClient = apiClient,
        _realtimeSocket = realtimeSocket;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final ApiClient _apiClient;
  final RealtimeSocket _realtimeSocket;

  @override
  Future<AuthSession?> restoreSession() async {
    final session = await _localDataSource.readSession();
    if (session == null) {
      return null;
    }
    _activateSession(session);
    return session;
  }

  @override
  Future<OtpRequest> requestOtp({
    required String phone,
    required String role,
  }) {
    return _remoteDataSource.requestOtp(phone: phone, role: role);
  }

  @override
  Future<AuthSession> signInWithOtp({
    required String phone,
    required String otp,
    required String role,
  }) async {
    final session =
        await _remoteDataSource.verifyOtp(phone: phone, otp: otp, role: role);
    await _localDataSource.saveSession(session);
    _activateSession(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    await _localDataSource.clearSession();
    _apiClient.accessToken = null;
    _apiClient.refreshToken = null;
    _realtimeSocket.dispose();
  }

  void _activateSession(AuthSession session) {
    _apiClient.accessToken = session.accessToken;
    _apiClient.refreshToken = session.refreshToken;
    _realtimeSocket.connect(session.accessToken);
  }
}
