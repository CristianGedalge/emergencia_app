import 'package:flutter/material.dart';

/// Pantalla temporal para roles cuya UX principal irá en la web o en fases posteriores.
class StubRoleScreen extends StatelessWidget {
  const StubRoleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onLogout,
  });

  final String title;
  final String subtitle;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text(
              'La gestión detallada de este rol está pensada principalmente para la aplicación web. '
              'Acá podés sumar después: lista de órdenes, estado de mecánicos, etc., cuando el backend exponga esos endpoints.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
