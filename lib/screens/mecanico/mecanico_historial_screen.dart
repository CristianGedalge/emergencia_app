import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../services/api_service.dart';
import 'mecanico_orden_screen.dart';

enum _FiltroHistorial { todos, finalizados }

class MecanicoHistorialScreen extends StatefulWidget {
  const MecanicoHistorialScreen({
    super.key,
    required this.mecanicoId,
  });

  final int mecanicoId;

  @override
  State<MecanicoHistorialScreen> createState() => _MecanicoHistorialScreenState();
}

class _MecanicoHistorialScreenState extends State<MecanicoHistorialScreen> {
  Future<List<SolicitudAuxilioVm>>? _futureApi;
  _FiltroHistorial _filtro = _FiltroHistorial.finalizados;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  void _cargarHistorial() {
    if (!ApiConfig.effectiveMockData) {
      setState(() {
        _futureApi = ApiService.instance.fetchServiciosMecanico();
      });
    }
  }

  Future<void> _onRefreshMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() {});
  }

  Future<void> _onRefreshApi() async {
    _cargarHistorial();
    await _futureApi;
    if (mounted) setState(() {});
  }

  List<SolicitudAuxilioVm> _filtrarLista(List<SolicitudAuxilioVm> original) {
    if (_filtro == _FiltroHistorial.finalizados) {
      return original.where((vm) => vm.solicitud.estado == EstadoSolicitud.finalizado).toList();
    }
    return original;
  }

  Color _colorEstado(EstadoSolicitud e, ColorScheme scheme) {
    switch (e) {
      case EstadoSolicitud.finalizado:
        return Colors.green;
      case EstadoSolicitud.cancelado:
        return Colors.red;
      case EstadoSolicitud.enSitio:
        return Colors.amber;
      case EstadoSolicitud.enCamino:
        return Colors.blue;
      case EstadoSolicitud.asignado:
        return scheme.primary;
      default:
        return scheme.outline;
    }
  }

  String _textoEstado(EstadoSolicitud e) {
    switch (e) {
      case EstadoSolicitud.finalizado:
        return 'Finalizado';
      case EstadoSolicitud.cancelado:
        return 'Cancelado';
      case EstadoSolicitud.enSitio:
        return 'En Sitio';
      case EstadoSolicitud.enCamino:
        return 'En Camino';
      case EstadoSolicitud.asignado:
        return 'Asignado';
      default:
        return 'Pendiente';
    }
  }

  String _formatearFecha(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} $h:$min';
  }

  Widget _buildLista(List<SolicitudAuxilioVm> source) {
    final list = _filtrarLista(source);

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                _filtro == _FiltroHistorial.finalizados
                    ? 'No tienes servicios realizados (finalizados) todavía.'
                    : 'No tienes servicios en tu historial.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final vm = list[i];
        final s = vm.solicitud;
        final color = _colorEstado(s.estado, scheme);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MecanicoOrdenScreen(
                    mecanicoId: widget.mecanicoId,
                    solicitudId: s.id,
                  ),
                ),
              );
              _cargarHistorial();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Servicio #${s.id}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          _textoEstado(s.estado),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        (vm.clienteNombre ?? '').trim().isNotEmpty
                            ? vm.clienteNombre!.trim()
                            : 'Cliente #${s.clienteId}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        _formatearFecha(s.fechaCreacion),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  if (s.tipoServicioNombre != null && s.tipoServicioNombre!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.build_outlined, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          s.tipoServicioNombre!,
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  if (s.descripcion != null && s.descripcion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      s.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SegmentedButton<_FiltroHistorial>(
        segments: const [
          ButtonSegment(
            value: _FiltroHistorial.finalizados,
            label: Text('Realizados'),
            icon: Icon(Icons.check_circle_outlined, size: 18),
          ),
          ButtonSegment(
            value: _FiltroHistorial.todos,
            label: Text('Todos'),
            icon: Icon(Icons.list_alt, size: 18),
          ),
        ],
        selected: {_filtro},
        onSelectionChanged: (set) => setState(() => _filtro = set.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('Mi Historial'),
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh),
          onPressed: _cargarHistorial,
        ),
      ],
    );

    if (ApiConfig.effectiveMockData) {
      return ListenableBuilder(
        listenable: MockDataStore.instance,
        builder: (context, _) {
          final source = MockDataStore.instance.ordenesParaMecanico(widget.mecanicoId);
          return Scaffold(
            appBar: appBar,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltros(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefreshMock,
                    child: _buildLista(source),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: appBar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFiltros(),
          Expanded(
            child: FutureBuilder<List<SolicitudAuxilioVm>>(
              future: _futureApi,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            'Error: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _cargarHistorial,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _onRefreshApi,
                  child: _buildLista(snap.data ?? []),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
