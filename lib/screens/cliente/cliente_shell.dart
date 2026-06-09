import 'package:flutter/material.dart';

import 'cliente_inicio_screen.dart';
import 'cliente_mapa_screen.dart';
import 'cliente_seguimiento_screen.dart';
import 'cuenta_cliente_screen.dart';
import 'emergencias_list_screen.dart';
import 'vehiculos_list_screen.dart';

class ClienteShell extends StatefulWidget {
  const ClienteShell({
    super.key,
    required this.clienteId,
    required this.onLogout,
    required this.isMockSession,
    this.nombreCliente,
  });

  final int clienteId;
  final VoidCallback onLogout;
  final bool isMockSession;
  final String? nombreCliente;

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ClienteInicioScreen(
        clienteId: widget.clienteId,
        nombreCliente: widget.nombreCliente,
        onPedirAuxilio: () async {
          await Navigator.of(context).pushNamed(
            '/cliente/nueva-emergencia',
            arguments: widget.clienteId,
          );
          if (mounted) setState(() {});
        },
        onIrSeguimiento: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ClienteSeguimientoScreen(clienteId: widget.clienteId),
            ),
          );
          if (mounted) setState(() {});
        },
        onIrTalleres: () => setState(() => _index = 1),
        onIrVehiculos: () => setState(() => _index = 2),
        onIrHistorial: () => setState(() => _index = 3),
      ),
      ClienteMapaScreen(clienteId: widget.clienteId),
      VehiculosListScreen(clienteId: widget.clienteId),
      EmergenciasListScreen(
        clienteId: widget.clienteId,
        mostrarSoloFinalizadas: false,
      ),
      CuentaClienteScreen(
        onLogout: widget.onLogout,
        isMockSession: widget.isMockSession,
        nombreCliente: widget.nombreCliente,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Talleres'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Vehículos'),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.of(context).pushNamed(
                  '/cliente/nueva-emergencia',
                  arguments: widget.clienteId,
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add_alert),
              label: const Text('Nueva emergencia'),
            )
          : null,
    );
  }
}
