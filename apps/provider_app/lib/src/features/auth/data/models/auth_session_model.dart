import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/auth_session.dart';

class AuthSessionModel extends AuthSession {
  const AuthSessionModel({
    required super.userId,
    required super.accessToken,
    required super.refreshToken,
    required super.user,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthSessionModel(
      userId: user['id'] as String,
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: user,
    );
  }

  factory AuthSessionModel.fromSupabaseSession({
    required Session? session,
    required String role,
    required String phone,
  }) {
    if (session == null) {
      throw StateError('Supabase OTP verification did not return a session.');
    }

    final user = session.user;
    return AuthSessionModel(
      userId: user.id,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
      user: {
        'id': user.id,
        'phone': user.phone ?? phone,
        'role': role,
      },
    );
  }
}
