import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'screens/auth_wrapper.dart';
import 'screens/cliente/emergencia_nueva_screen.dart';
import 'screens/register_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Si falta google-services.json correcto, la app sigue funcionando sin push.
    }
    
    // Inicializar Stripe
    Stripe.publishableKey = 'pk_test_51TgOCMAuAFAKZD0gzEOcs392xHpAHV247L2WNolodi4g6CG1ktjFouXIqzpitU9Sgvcp6sLTJkT0xmMWV2aVHUeR00cFCS2GcK';
    await Stripe.instance.applySettings();
  }
  runApp(const EmergenciaMovilApp());
}

class EmergenciaMovilApp extends StatelessWidget {
  const EmergenciaMovilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergencia vehicular',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/register': (_) => const RegisterScreen(),
        '/cliente/nueva-emergencia': (ctx) {
          final id = ModalRoute.of(ctx)!.settings.arguments;
          final clienteId = id is int ? id : int.parse('$id');
          return EmergenciaNuevaScreen(clienteId: clienteId);
        },
      },
    );
  }
}
