import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../models/vehiculo.dart';
import '../../services/api_service.dart';
import '../../services/session_service.dart';
import '../../utils/google_maps_links.dart';
import '../../utils/telefono_launch.dart';
import 'mecanico_orden_screen.dart';

/// Una sola orden prioritaria asignada por el taller (web). Sin lista tipo administrador.
class MecanicoMiServicioScreen extends StatefulWidget {
  const MecanicoMiServicioScreen({super.key, required this.mecanicoId});

  final int mecanicoId;

  @override
  State<MecanicoMiServicioScreen> createState() => _MecanicoMiServicioScreenState();
}

class _MecanicoMiServicioScreenState extends State<MecanicoMiServicioScreen> {
  late Future<_ApiMecanicoVistaData> _apiVistaFuture;

  @override
  void initState() {
    super.initState();
    _apiVistaFuture = _cargarApiVista();
  }

  void _refrescarAsignacionApi() {
    setState(() {
      _apiVistaFuture = _cargarApiVista();
    });
  }

  Future<void> _llamarCliente(BuildContext context, String telefono) async {
    try {
      final ok = await abrirLlamadaTelefono(telefono);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada.')),
        );
      }
    }
  }

  Future<void> _abrirUri(BuildContext context, Uri uri) async {
    try {
      final ok = await GoogleMapsLinks.open(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace de mapas.')),
        );
      }
    }
  }

  Widget _bloqueVehiculo(BuildContext context, Vehiculo v) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(Icons.directions_car, color: scheme.onPrimaryContainer),
      ),
      title: const Text('Vehículo del cliente'),
      subtitle: Text(
        '${v.marca} ${v.modelo} · ${v.placa}'
        '${v.color != null && v.color!.trim().isNotEmpty ? ' · ${v.color}' : ''} · ${v.anio}',
      ),
    );
  }

  Widget _bloqueFotoCliente(BuildContext context, SolicitudAuxilio s) {
    final scheme = Theme.of(context).colorScheme;
    final urls = (s.urlsFotos != null && s.urlsFotos!.isNotEmpty) 
        ? s.urlsFotos! 
        : (s.urlImg != null && s.urlImg!.trim().isNotEmpty ? [s.urlImg!] : <String>[]);
        
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              urls.length > 1 ? 'Fotos del cliente' : 'Foto del cliente',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (urls.isEmpty || urls.first.isEmpty)
          Text(
            'En este pedido el cliente no adjuntó foto. Cuando el API guarde una URL pública (HTTPS), se verá acá en miniatura.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          )
        else if (urls.length == 1)
          _buildSingleFoto(context, urls.first)
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _buildSingleFoto(context, urls[i], width: 250),
            ),
          ),
        
        if (s.urlAudio != null && s.urlAudio!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.mic_none_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'El cliente adjuntó nota de audio. En esta vista solo se indica; la reproducción completa iría con un reproductor cuando el API entregue un archivo o URL HTTPS.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSingleFoto(BuildContext context, String url, {double? width}) {
    final scheme = Theme.of(context).colorScheme;
    final cleanUrl = url.trim();
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              cleanUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No se pudo cargar la imagen. Revisá la URL o permisos CORS en web.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: width,
        child: Text(
          'Hay referencia a imagen (demo u archivo local: $cleanUrl). En producción el backend debe devolver un enlace HTTPS accesible para mostrarla acá.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
  }

  SolicitudAuxilioVm? _ordenPrioritaria() {
    MockDataStore.instance.ensureSeed();
    final activa = MockDataStore.instance.solicitudSeguimientoPrioritariaMecanico(widget.mecanicoId);
    if (activa != null) return activa;
    final todas = MockDataStore.instance.ordenesParaMecanico(widget.mecanicoId);
    if (todas.isEmpty) return null;
    todas.sort((a, b) => b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion));
    return todas.first;
  }

  Future<_ApiMecanicoVistaData> _cargarApiVista() async {
    final token = await SessionService.instance.readToken();
    if (token == null || token.isEmpty) {
      return const _ApiMecanicoVistaData();
    }
    final claims = SessionService.instance.claims(token);
    SolicitudAuxilioVm? servicioAsignado;
    String? servicioError;
    try {
      servicioAsignado = await ApiService.instance.fetchMiServicioMecanico();
    } catch (e) {
      servicioError = e.toString();
    }

    return _ApiMecanicoVistaData(
      nombre: claims['nombre'] as String?,
      telefono: claims['telefono'] as String?,
      tallerId: (claims['tallerId'] as num?)?.toInt(),
      mecanicoIdClaim: (claims['mecanicoId'] as num?)?.toInt(),
      servicioAsignado: servicioAsignado,
      servicioError: servicioError,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.effectiveMockData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi servicio'),
          actions: [
            IconButton(
              tooltip: 'Actualizar asignación',
              onPressed: _refrescarAsignacionApi,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<_ApiMecanicoVistaData>(
          future: _apiVistaFuture,
          builder: (context, snapshot) {
            final data = snapshot.data ?? const _ApiMecanicoVistaData();
            final scheme = Theme.of(context).colorScheme;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu perfil mecánico',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Mecánico: ${data.nombre?.trim().isNotEmpty == true ? data.nombre!.trim() : 'Mecánico #${data.mecanicoIdClaim ?? widget.mecanicoId}'}',
                        ),
                        Text('Taller: ${data.tallerId != null ? 'Taller ${data.tallerId}' : 'Taller asignado'}'),
                        if (data.telefono?.trim().isNotEmpty == true) Text('Teléfono: ${data.telefono!.trim()}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_outlined, color: scheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Estado de asignación',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data.servicioAsignado == null
                              ? 'No tienes nada asignado.'
                              : 'Tienes una solicitud asignada (#${data.servicioAsignado!.solicitud.id}).',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        if (data.servicioError != null && data.servicioError!.trim().isNotEmpty)
                          Text(
                            'No se pudo actualizar en este momento. Intenta nuevamente.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.error,
                                ),
                          )
                        else
                          Text(
                            data.servicioAsignado == null
                                ? 'Cuando el admin del taller te asigne una solicitud, aparecerá aquí.'
                                : 'Ya puedes abrir el detalle, avance y cobro del servicio asignado.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: data.servicioAsignado == null
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => MecanicoOrdenScreen(
                                        mecanicoId: data.mecanicoIdClaim ?? widget.mecanicoId,
                                        solicitudId: data.servicioAsignado!.solicitud.id,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Ver solicitud asignada'),
                        ),
                        if (data.servicioAsignado != null) ...[
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () => _abrirUri(
                              context,
                              GoogleMapsLinks.drivingToDestination(
                                data.servicioAsignado!.solicitud.latitud,
                                data.servicioAsignado!.solicitud.longitud,
                              ),
                            ),
                            icon: const Icon(Icons.navigation),
                            label: const Text('Ir a ubicación del cliente'),
                          ),
                          if (data.servicioAsignado!.clienteTelefono != null &&
                              data.servicioAsignado!.clienteTelefono!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _llamarCliente(context, data.servicioAsignado!.clienteTelefono!),
                              icon: const Icon(Icons.call),
                              label: const Text('Llamar al cliente'),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return ListenableBuilder(
      listenable: MockDataStore.instance,
      builder: (context, _) {
        final vm = _ordenPrioritaria();
        final scheme = Theme.of(context).colorScheme;
        final vehiculo = vm != null
            ? MockDataStore.instance.vehiculoPorIdGlobal(vm.solicitud.vehiculoId)
            : null;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Mi servicio'),
                Text(
                  'Mecánico #${widget.mecanicoId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                ),
              ],
            ),
          ),
          body: vm == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, size: 64, color: scheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'Sin orden asignada',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'El administrador del taller te asigna el pedido desde la aplicación web. '
                          'Cuando haya una asignación, aparecerá acá con el botón para iniciar la ruta.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Orden asignada al taller',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Solicitud #${vm.solicitud.id}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vm.solicitud.estado.valorApi,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (vm.tallerNombreAsignado != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Taller: ${vm.tallerNombreAsignado}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            if (vm.solicitud.descripcion != null &&
                                vm.solicitud.descripcion!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                vm.solicitud.descripcion!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                            if (vm.mecanicoId != null) ...[
                              const Divider(height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.phone_in_talk_outlined, color: scheme.primary, size: 28),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Cliente · contacto',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Text(
                                          'Cliente #${vm.solicitud.clienteId}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (vm.clienteTelefono != null &&
                                            vm.clienteTelefono!.trim().isNotEmpty) ...[
                                          SelectableText(
                                            vm.clienteTelefono!.trim(),
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                          const SizedBox(height: 10),
                                          FilledButton.tonalIcon(
                                            onPressed: () => _llamarCliente(context, vm.clienteTelefono!),
                                            icon: const Icon(Icons.call_rounded),
                                            label: const Text('Llamar al cliente'),
                                          ),
                                        ] else
                                          Text(
                                            'El cliente no cargó número de teléfono en su cuenta. '
                                            'Cuando el API envíe `telefono` del usuario, aparecerá acá tras la asignación.',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              'Ubicación del auxilio:\n'
                              '${vm.solicitud.latitud.toStringAsFixed(5)}, ${vm.solicitud.longitud.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            if (vehiculo != null) ...[
                              const Divider(height: 24),
                              _bloqueVehiculo(context, vehiculo),
                            ],
                            const Divider(height: 24),
                            _bloqueFotoCliente(context, vm.solicitud),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _abrirUri(
                        context,
                        GoogleMapsLinks.drivingToDestination(
                          vm.solicitud.latitud,
                          vm.solicitud.longitud,
                        ),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      label: const Text('Iniciar ruta (Google Maps)'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se abre Google Maps con la ruta en conducción hasta el punto del auxilio.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MecanicoOrdenScreen(
                              mecanicoId: widget.mecanicoId,
                              solicitudId: vm.solicitud.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Detalle, avance y cobro'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ApiMecanicoVistaData {
  const _ApiMecanicoVistaData({
    this.nombre,
    this.telefono,
    this.tallerId,
    this.mecanicoIdClaim,
    this.servicioAsignado,
    this.servicioError,
  });

  final String? nombre;
  final String? telefono;
  final int? tallerId;
  final int? mecanicoIdClaim;
  final SolicitudAuxilioVm? servicioAsignado;
  final String? servicioError;
}
