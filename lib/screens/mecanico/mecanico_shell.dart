import 'package:flutter/material.dart';

import 'cuenta_mecanico_screen.dart';
import 'mecanico_historial_screen.dart';
import 'mecanico_mi_servicio_screen.dart';

/// Rol **mecánico**: una sola orden asignada (vista web del taller) + cuenta.
class MecanicoShell extends StatefulWidget {
  const MecanicoShell({
    super.key,
    required this.mecanicoId,
    required this.onLogout,
    required this.isMockSession,
    this.nombre,
  });

  final int mecanicoId;
  final VoidCallback onLogout;
  final bool isMockSession;
  final String? nombre;

  @override
  State<MecanicoShell> createState() => _MecanicoShellState();
}

class _MecanicoShellState extends State<MecanicoShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MecanicoMiServicioScreen(mecanicoId: widget.mecanicoId),
      MecanicoHistorialScreen(mecanicoId: widget.mecanicoId),
      CuentaMecanicoScreen(
        onLogout: widget.onLogout,
        isMockSession: widget.isMockSession,
        nombre: widget.nombre,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Servicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}
