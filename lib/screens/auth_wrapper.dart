import 'package:flutter/material.dart';

import '../models/mock_session.dart';
import '../services/push_service.dart';
import '../services/session_service.dart';
import 'login_screen.dart';
import 'role_shell.dart';

/// Arranque: sesión mock guardada, JWT válido, o pantalla de login.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _session = SessionService.instance;
  bool _loading = true;
  String? _token;
  MockSession? _mockSession;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _mockSession = await _session.readMockSession();
    if (_mockSession == null) {
      final t = await _session.readToken();
      if (t != null && _session.tokenValido(t)) {
        _token = t;
        await PushService.instance.initAndSyncToken();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onLoggedIn(String token) {
    setState(() {
      _token = token;
      _mockSession = null;
    });
  }

  void _onMockLoggedIn(MockSession session) {
    setState(() {
      _mockSession = session;
      _token = null;
    });
  }

  Future<void> _onLogout() async {
    await _session.clear();
    PushService.instance.clearTokenTracking();
    if (mounted) {
      setState(() {
        _token = null;
        _mockSession = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_token == null && _mockSession == null) {
      return LoginScreen(
        onLoggedIn: _onLoggedIn,
        onMockLoggedIn: _onMockLoggedIn,
      );
    }
    return RoleShell(
      token: _token,
      mockSession: _mockSession,
      onLogout: _onLogout,
    );
  }
}
