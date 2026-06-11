import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../repositories/solicitudes_repository.dart';
import '../../repositories/vehiculos_repository.dart';
import 'cliente_estilos_solicitud.dart';
import 'emergencia_detalle_screen.dart';

/// Pantalla principal del cliente: resumen, pedido activo y acceso rápido (patrón tipo apps de auxilio en ruta).
class ClienteInicioScreen extends StatelessWidget {
  const ClienteInicioScreen({
    super.key,
    required this.clienteId,
    this.nombreCliente,
    required this.onPedirAuxilio,
    required this.onIrSeguimiento,
    required this.onIrTalleres,
    required this.onIrVehiculos,
    required this.onIrHistorial,
  });

  final int clienteId;
  final String? nombreCliente;
  final VoidCallback onPedirAuxilio;
  final VoidCallback onIrSeguimiento;
  final VoidCallback onIrTalleres;
  final VoidCallback onIrVehiculos;
  final VoidCallback onIrHistorial;

  SolicitudAuxilioVm? _pedidoActivo(List<SolicitudAuxilioVm> todas) {
    final abiertas = todas.where((vm) => solicitudSigueAbierta(vm.solicitud)).toList();
    if (abiertas.isEmpty) return null;
    abiertas.sort((a, b) => b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion));
    return abiertas.first;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nombre = (nombreCliente != null && nombreCliente!.trim().isNotEmpty)
        ? nombreCliente!.trim().split(' ').first
        : 'Cliente';

    Widget body;
    if (!ApiConfig.effectiveMockData) {
      body = _InicioApiBody(
        clienteId: clienteId,
        nombre: nombre,
        onPedirAuxilio: onPedirAuxilio,
        onIrSeguimiento: onIrSeguimiento,
        onIrTalleres: onIrTalleres,
        onIrVehiculos: onIrVehiculos,
        onIrHistorial: onIrHistorial,
        pedidoActivoResolver: _pedidoActivo,
      );
    } else {
      body = ListenableBuilder(
        listenable: MockDataStore.instance,
        builder: (context, _) {
          final todas = MockDataStore.instance.solicitudesDeCliente(clienteId);
          final activa = _pedidoActivo(todas);
          final vehiculos = MockDataStore.instance.vehiculosActivosDeCliente(clienteId);
          final puedePedir = vehiculos.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Hola, $nombre',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '¿Necesitás auxilio en ruta?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: puedePedir
                    ? onPedirAuxilio
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Primero agregá un vehículo en la pestaña Vehículos.'),
                          ),
                        );
                        onIrVehiculos();
                      },
                icon: const Icon(Icons.emergency_share_rounded, size: 26),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                label: Text(puedePedir ? 'Pedir auxilio ahora' : 'Agregar vehículo para pedir auxilio'),
              ),
              const SizedBox(height: 24),
              if (activa != null) ...[
                Text('Tu pedido activo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _TarjetaPedidoActivo(
                  vm: activa,
                  clienteId: clienteId,
                  onVerDetalle: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EmergenciaDetalleScreen(
                          clienteId: clienteId,
                          solicitudId: activa.solicitud.id,
                        ),
                      ),
                    );
                  },
                  onSeguimiento: onIrSeguimiento,
                ),
                const SizedBox(height: 24),
              ] else ...[
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: scheme.primary, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'No tenés pedidos abiertos. Cuando solicites auxilio, el estado aparecerá acá.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text('Accesos rápidos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _QuickTile(
                icon: Icons.map_outlined,
                title: 'Talleres cercanos',
                subtitle: 'Mapa y teléfonos',
                onTap: onIrTalleres,
              ),
              _QuickTile(
                icon: Icons.directions_car_outlined,
                title: 'Mis vehículos',
                subtitle: '${vehiculos.length} registrado${vehiculos.length == 1 ? '' : 's'}',
                onTap: onIrVehiculos,
              ),
              _QuickTile(
                icon: Icons.route_outlined,
                title: 'Seguimiento en mapa',
                subtitle: 'Cuando haya mecánico asignado',
                onTap: onIrSeguimiento,
              ),
              _QuickTile(
                icon: Icons.payments_outlined,
                title: 'Pagos',
                subtitle: 'Pendiente de integración backend',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pagos aún no está integrado con API.'),
                    ),
                  );
                },
              ),
              _QuickTile(
                icon: Icons.history_outlined,
                title: 'Historial',
                subtitle: 'Servicios finalizados',
                onTap: onIrHistorial,
              ),
              const SizedBox(height: 16),
              Text(
                'Los talleres gestionan y asignan pedidos desde la web. En el móvil ves tu pedido activo acá arriba y el seguimiento en la pestaña correspondiente.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        centerTitle: false,
      ),
      body: body,
    );
  }
}

class _InicioApiData {
  const _InicioApiData({
    required this.solicitudes,
    required this.vehiculosActivos,
  });

  final List<SolicitudAuxilioVm> solicitudes;
  final int vehiculosActivos;
}

class _InicioApiBody extends StatefulWidget {
  const _InicioApiBody({
    required this.clienteId,
    required this.nombre,
    required this.onPedirAuxilio,
    required this.onIrSeguimiento,
    required this.onIrTalleres,
    required this.onIrVehiculos,
    required this.onIrHistorial,
    required this.pedidoActivoResolver,
  });

  final int clienteId;
  final String nombre;
  final VoidCallback onPedirAuxilio;
  final VoidCallback onIrSeguimiento;
  final VoidCallback onIrTalleres;
  final VoidCallback onIrVehiculos;
  final VoidCallback onIrHistorial;
  final SolicitudAuxilioVm? Function(List<SolicitudAuxilioVm>) pedidoActivoResolver;

  @override
  State<_InicioApiBody> createState() => _InicioApiBodyState();
}

class _InicioApiBodyState extends State<_InicioApiBody> {
  Future<_InicioApiData> _cargar() async {
    final vehiculos = await vehiculosRepository().listarPorCliente(widget.clienteId);
    List<SolicitudAuxilioVm> solicitudes;
    try {
      solicitudes = await solicitudesRepository().listarPorCliente(widget.clienteId);
    } catch (_) {
      solicitudes = const [];
    }
    return _InicioApiData(
      solicitudes: solicitudes,
      vehiculosActivos: vehiculos.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_InicioApiData>(
      future: _cargar(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data;
        final solicitudes = data?.solicitudes ?? const <SolicitudAuxilioVm>[];
        final vehiculosActivos = data?.vehiculosActivos ?? 0;
        final activa = widget.pedidoActivoResolver(solicitudes);
        final historial = solicitudes
            .where((vm) => activa == null || vm.solicitud.id != activa.solicitud.id)
            .toList();
        final puedePedir = vehiculosActivos > 0;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Hola, ${widget.nombre}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 4),
            Text(
              '¿Necesitás auxilio en ruta?',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: puedePedir
                  ? widget.onPedirAuxilio
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Primero agregá un vehículo en la pestaña Vehículos.'),
                        ),
                      );
                      widget.onIrVehiculos();
                    },
              icon: const Icon(Icons.emergency_share_rounded, size: 26),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              label: Text(puedePedir ? 'Pedir auxilio ahora' : 'Agregar vehículo para pedir auxilio'),
            ),
            const SizedBox(height: 24),
            if (activa != null) ...[
              Text('Tu pedido activo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _TarjetaPedidoActivo(
                vm: activa,
                clienteId: widget.clienteId,
                onVerDetalle: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EmergenciaDetalleScreen(
                        clienteId: widget.clienteId,
                        solicitudId: activa.solicitud.id,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                onSeguimiento: widget.onIrSeguimiento,
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 8),
            if (historial.isNotEmpty) ...[
              Text('Pedidos recientes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...historial.take(3).map(
                (vm) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text('Solicitud #${vm.solicitud.id}'),
                    subtitle: Text(etiquetaEstadoBreve(vm.solicitud.estado)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EmergenciaDetalleScreen(
                            clienteId: widget.clienteId,
                            solicitudId: vm.solicitud.id,
                          ),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Accesos rápidos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _QuickTile(
              icon: Icons.map_outlined,
              title: 'Talleres cercanos',
              subtitle: 'Mapa y teléfonos',
              onTap: widget.onIrTalleres,
            ),
            _QuickTile(
              icon: Icons.directions_car_outlined,
              title: 'Mis vehículos',
              subtitle: '$vehiculosActivos registrado${vehiculosActivos == 1 ? '' : 's'}',
              onTap: widget.onIrVehiculos,
            ),

            _QuickTile(
              icon: Icons.history_outlined,
              title: 'Historial',
              subtitle: 'Servicios finalizados',
              onTap: widget.onIrHistorial,
            ),
          ],
        ));
      },
    );
  }
}

class _TarjetaPedidoActivo extends StatelessWidget {
  const _TarjetaPedidoActivo({
    required this.vm,
    required this.clienteId,
    required this.onVerDetalle,
    required this.onSeguimiento,
  });

  final SolicitudAuxilioVm vm;
  final int clienteId;
  final VoidCallback onVerDetalle;
  final VoidCallback onSeguimiento;

  @override
  Widget build(BuildContext context) {
    final s = vm.solicitud;
    final scheme = Theme.of(context).colorScheme;
    final color = colorPorEstadoSolicitud(s.estado, scheme);
    final seguimiento = vm.mecanicoId != null &&
        (s.estado == EstadoSolicitud.asignado ||
            s.estado == EstadoSolicitud.enCamino ||
            s.estado == EstadoSolicitud.enSitio ||
            s.estado == EstadoSolicitud.finalizado);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etiquetaEstadoBreve(s.estado),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                      Text(
                        'Solicitud #${s.id}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vm.tallerNombreAsignado != null)
                  Text('Taller: ${vm.tallerNombreAsignado}', style: Theme.of(context).textTheme.bodyMedium),
                if (s.descripcion != null && s.descripcion!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.descripcion!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onVerDetalle,
                        child: const Text('Ver detalle'),
                      ),
                    ),
                    if (seguimiento) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onSeguimiento,
                          icon: Icon(s.estado == EstadoSolicitud.finalizado ? Icons.payment : Icons.map),
                          label: Text(s.estado == EstadoSolicitud.finalizado ? 'Pagar' : 'Mapa'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
