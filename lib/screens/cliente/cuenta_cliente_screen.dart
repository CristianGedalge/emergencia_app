import 'package:flutter/material.dart';

import '../../config/api_config.dart';

class CuentaClienteScreen extends StatelessWidget {
  const CuentaClienteScreen({
    super.key,
    required this.onLogout,
    required this.isMockSession,
    this.nombreCliente,
  });

  final VoidCallback onLogout;
  final bool isMockSession;
  final String? nombreCliente;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raw = (nombreCliente ?? '').trim();
    final nombre = raw.isEmpty ? 'Cliente' : raw;

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            elevation: 0,
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary,
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 22, color: scheme.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMockSession ? 'Sesión de demostración' : 'Sesión con servidor',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (ApiConfig.effectiveMockData) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.science_outlined, color: scheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Modo MOCK: vehículos, pedidos y pagos viven solo en el dispositivo. '
                        'Para API real: flutter run --dart-define=MOCK=false',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Ajustes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: const Text(
                    'Activadas para avisos de tu servicio y cambios de estado.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notificaciones activas.')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Ubicación'),
                  subtitle: const Text('Se usa para enviar el punto del auxilio y el mapa de seguimiento.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configurá permisos en Ajustes del sistema → la app.')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Cómo funciona'),
                  subtitle: const Text(
                    'Pedís auxilio → los talleres lo ven en la web → uno acepta y asigna mecánico → seguís el mapa.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.tonal(
            onPressed: onLogout,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
