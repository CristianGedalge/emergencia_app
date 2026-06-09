import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_service.dart';

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _initialized = false;
  String? _lastTokenSent;

  Future<void> initAndSyncToken() async {
    if (kIsWeb) {
      debugPrint("ℹ️ PushService: Ignorado en Web.");
      return;
    }

    try {
      debugPrint("🔑 Inicializando PushService...");
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await messaging.getToken();
      debugPrint("🔑 Token FCM obtenido: $token");
      if (token != null && token.isNotEmpty) {
        await _sendTokenIfNeeded(token);
      } else {
        debugPrint("⚠️ Token FCM obtenido es vacío o nulo.");
      }

      if (!_initialized) {
        _initialized = true;
        FirebaseMessaging.onMessage.listen((RemoteMessage _) {
          debugPrint("📩 Notificación recibida en primer plano.");
        });
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          debugPrint("🔄 Token FCM refrescado: $newToken");
          await _sendTokenIfNeeded(newToken, force: true);
        });
      }
    } catch (e, stack) {
      debugPrint("❌ Error en Firebase / PushService: $e");
      debugPrint(stack.toString());
    }
  }

  Future<void> _sendTokenIfNeeded(String token, {bool force = false}) async {
    if (!force && _lastTokenSent == token) {
      debugPrint("ℹ️ El token FCM ya fue enviado anteriormente.");
      return;
    }
    debugPrint("🚀 Enviando token FCM a la API: $token");
    try {
      await ApiService.instance.updateFcmToken(token);
      _lastTokenSent = token;
      debugPrint("✅ Token FCM registrado exitosamente en la API.");
    } catch (e) {
      debugPrint("❌ Error enviando token FCM a la API: $e");
    }
  }

  void clearTokenTracking() {
    debugPrint("🧹 Reseteando tracking de token FCM (Logout).");
    _lastTokenSent = null;
  }
}
