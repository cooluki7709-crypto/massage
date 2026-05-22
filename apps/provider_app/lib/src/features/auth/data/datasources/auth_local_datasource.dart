import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_session_model.dart';

class AuthLocalDataSource {
  const AuthLocalDataSource({
    required FlutterSecureStorage storage,
    required String storageKey,
  })  : _storage = storage,
        _storageKey = storageKey;

  final FlutterSecureStorage _storage;
  final String _storageKey;

  Future<void> saveSession(AuthSessionModel session) {
    return _storage.write(
      key: _storageKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<AuthSessionModel?> readSession() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clearSession();
        return null;
      }
      return AuthSessionModel.fromJson(decoded);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() {
    return _storage.delete(key: _storageKey);
  }
}
