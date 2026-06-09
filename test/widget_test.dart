import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:emergencia_movil/screens/login_screen.dart';

void main() {
  testWidgets('Pantalla de login muestra campos principales', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onLoggedIn: (_) {}),
      ),
    );

    expect(find.text('Iniciá sesión para continuar'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
  });
}
