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
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const FormatException('Auth response is missing user data.');
    }

    final user = Map<String, dynamic>.from(rawUser);
    final userId = user['id']?.toString();
    final accessToken = json['accessToken']?.toString();
    final refreshToken = json['refreshToken']?.toString() ?? '';
    if (userId == null ||
        userId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      throw const FormatException('Auth response is missing required tokens.');
    }

    return AuthSessionModel(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
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
