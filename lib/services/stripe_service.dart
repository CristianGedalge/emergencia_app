import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'session_service.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  /// Crea el Payment Intent en el Backend y abre la ventana de pago de Stripe.
  /// Si el pago es exitoso, llama al backend para confirmarlo.
  Future<bool> procesarPago({
    required int solicitudId,
    required List<Map<String, dynamic>> cobrosExtra,
  }) async {
    try {
      // 1. Llamar al backend para crear el Payment Intent
      final intentResponse = await _createPaymentIntent(solicitudId, cobrosExtra);
      if (intentResponse == null) return false;

      final clientSecret = intentResponse['client_secret'];

      // 2. Inicializar la hoja de pago (Payment Sheet) en la UI nativa
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Emergencia Vehicular',
          style: ThemeMode.light,
        ),
      );

      // 3. Mostrar la hoja de pago al usuario
      await Stripe.instance.presentPaymentSheet();

      // 4. Si el pago fue exitoso (no lanzó excepción), confirmamos en el backend
      // NOTA: Stripe no devuelve un ID fácil aquí, enviamos 'pagado_por_movil'
      final confirmado = await _confirmarPagoBackend(solicitudId, 'pagado_por_movil');
      
      return confirmado;

    } on StripeException catch (e) {
      debugPrint('Error Stripe: ${e.error.localizedMessage}');
      return false;
    } catch (e) {
      debugPrint('Error General Pago: $e');
      return false;
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await SessionService.instance.readToken();
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> _createPaymentIntent(int solicitudId, List<Map<String, dynamic>> cobrosExtra) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/pagos/intent');
    try {
      final headers = await _getAuthHeaders();
      
      final body = jsonEncode({
        'solicitud_id': solicitudId,
        'cobros_extra': cobrosExtra,
      });

      final res = await http.post(url, headers: headers, body: body);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        debugPrint('Error creando intent: ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error http intent: $e');
      return null;
    }
  }

  Future<bool> _confirmarPagoBackend(int solicitudId, String stripePaymentId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/pagos/confirmar');
    try {
      final headers = await _getAuthHeaders();
      
      final body = jsonEncode({
        'solicitud_id': solicitudId,
        'stripe_payment_id': stripePaymentId,
      });

      final res = await http.post(url, headers: headers, body: body);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('Error http confirmar: $e');
      return false;
    }
  }
}
