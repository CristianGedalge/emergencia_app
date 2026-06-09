import 'package:flutter/material.dart';

import '../../config/api_config.dart';

class CuentaMecanicoScreen extends StatelessWidget {
  const CuentaMecanicoScreen({
    super.key,
    required this.onLogout,
    required this.isMockSession,
    this.nombre,
  });

  final VoidCallback onLogout;
  final bool isMockSession;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (ApiConfig.effectiveMockData)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Sesión de demostración: los datos no salen del teléfono hasta que conectes el API.',
                ),
              ),
            ),
          if (ApiConfig.effectiveMockData) const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.build),
            title: Text(nombre ?? 'Mecánico'),
            subtitle: Text(isMockSession ? 'Demo (sin JWT)' : 'Sesión servidor'),
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(onPressed: onLogout, child: const Text('Cerrar sesión')),
        ],
      ),
    );
  }
}
