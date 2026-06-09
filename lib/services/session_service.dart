import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mock_session.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _kToken = 'access_token';
  static const _kMock = 'mock_session_v1';

  final _storage = const FlutterSecureStorage();

  /// Copia en memoria de la sesión mock (para [ApiConfig.effectiveMockData] sin import async).
  MockSession? _activeMockSession;

  bool get hasActiveMockSession => _activeMockSession != null;

  Future<void> saveToken(String token) async {
    await clearMockSession();
    await _storage.write(key: _kToken, value: token);
  }

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> saveMockSession(MockSession session) async {
    _activeMockSession = session;
    await _storage.delete(key: _kToken);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMock, jsonEncode(session.toJson()));
  }

  Future<MockSession?> readMockSession() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kMock);
    if (raw == null) {
      _activeMockSession = null;
      return null;
    }
    try {
      _activeMockSession =
          MockSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _activeMockSession;
    } catch (_) {
      _activeMockSession = null;
      return null;
    }
  }

  Future<void> clearMockSession() async {
    _activeMockSession = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kMock);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await clearMockSession();
  }

  bool tokenValido(String token) {
    try {
      return !JwtDecoder.isExpired(token);
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> claims(String token) => JwtDecoder.decode(token);

  String? rol(String token) => claims(token)['rol'] as String?;

  int? clienteIdFromToken(String token) {
    try {
      final sub = claims(token)['sub'] as String?;
      if (sub == null) return null;
      return int.tryParse(sub);
    } catch (_) {
      return null;
    }
  }
}
