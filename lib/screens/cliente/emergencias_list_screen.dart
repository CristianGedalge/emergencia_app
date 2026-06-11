import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../repositories/solicitudes_repository.dart';
import 'cliente_estilos_solicitud.dart';
import 'emergencia_detalle_screen.dart';

enum _FiltroLista { activas, finalizadas, todas }

class EmergenciasListScreen extends StatefulWidget {
  const EmergenciasListScreen({
    super.key,
    required this.clienteId,
    this.mostrarSoloFinalizadas = false,
  });

  final int clienteId;
  final bool mostrarSoloFinalizadas;

  @override
  State<EmergenciasListScreen> createState() => _EmergenciasListScreenState();
}

class _EmergenciasListScreenState extends State<EmergenciasListScreen> {
  final _repo = solicitudesRepository();
  Future<List<SolicitudAuxilioVm>>? _futureApi;
  _FiltroLista _filtro = _FiltroLista.activas;

  @override
  void initState() {
    super.initState();
    if (widget.mostrarSoloFinalizadas) {
      _filtro = _FiltroLista.finalizadas;
    }
    if (!ApiConfig.effectiveMockData) {
      _futureApi = _repo.listarPorCliente(widget.clienteId);
    }
  }

  void _refreshApi() {
    if (!ApiConfig.effectiveMockData) {
      setState(() {
        _futureApi = _repo.listarPorCliente(widget.clienteId);
      });
    }
  }

  List<SolicitudAuxilioVm> _aplicarFiltro(List<SolicitudAuxilioVm> list) {
    switch (_filtro) {
      case _FiltroLista.activas:
        return list.where((vm) => solicitudSigueAbierta(vm.solicitud)).toList();
      case _FiltroLista.finalizadas:
        return list.where((vm) => vm.solicitud.estado == EstadoSolicitud.finalizado).toList();
      case _FiltroLista.todas:
        return list;
    }
  }

  Future<void> _onRefreshMock() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) setState(() {});
  }

  Future<void> _onRefreshApi() async {
    _refreshApi();
    await _futureApi;
    if (mounted) setState(() {});
  }

  Widget _list(List<SolicitudAuxilioVm> source) {
    final list = _aplicarFiltro(source);
    if (source.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                ApiConfig.effectiveMockData
                    ? 'Todavía no pediste auxilio.'
                    : 'Todavía no hay solicitudes para mostrar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (ApiConfig.effectiveMockData) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/cliente/nueva-emergencia', arguments: widget.clienteId);
                  },
                  icon: const Icon(Icons.add_alert),
                  label: const Text('Pedir auxilio'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _filtro == _FiltroLista.activas
                ? 'No tenés pedidos activos. Probá “Todas” para ver el historial.'
                : _filtro == _FiltroLista.finalizadas
                    ? 'Historial vacío: todavía no tenés servicios finalizados.'
                    : 'Nada que mostrar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final vm = list[i];
        final s = vm.solicitud;
        final color = colorPorEstadoSolicitud(s.estado, scheme);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EmergenciaDetalleScreen(
                    clienteId: widget.clienteId,
                    solicitudId: s.id,
                  ),
                ),
              );
              if (mounted) _refreshApi();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Solicitud #${s.id}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          etiquetaEstadoBreve(s.estado),
                          style: const TextStyle(fontSize: 12),
                        ),
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        backgroundColor: color.withValues(alpha: 0.12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (vm.tallerNombreAsignado != null)
                    Row(
                      children: [
                        Icon(Icons.storefront_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vm.tallerNombreAsignado!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  if (vm.mecanicoNombre != null && vm.mecanicoNombre!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.build_circle_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mecánico: ${vm.mecanicoNombre}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (s.precioEstimado != null || s.precioFinal != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        if (s.precioEstimado != null)
                          Text(
                            'Est: ${s.precioEstimado!.toStringAsFixed(2)} Bs',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (s.precioFinal != null) ...[
                          if (s.precioEstimado != null) const SizedBox(width: 12),
                          Text(
                            'Final: ${s.precioFinal!.toStringAsFixed(2)} Bs',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (s.descripcion != null && s.descripcion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      s.descripcion!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        s.estado.valorApi,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline),
                      ),
                      const Spacer(),
                      Text('Tocá para ver detalle', style: Theme.of(context).textTheme.labelSmall),
                      Icon(Icons.chevron_right, size: 18, color: scheme.outline),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filtroBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SegmentedButton<_FiltroLista>(
        segments: const [
          ButtonSegment(
            value: _FiltroLista.activas,
            label: Text('Activas'),
            icon: Icon(Icons.pending_actions_outlined, size: 18),
          ),
          ButtonSegment(
            value: _FiltroLista.todas,
            label: Text('Todas'),
            icon: Icon(Icons.history, size: 18),
          ),
          ButtonSegment(
            value: _FiltroLista.finalizadas,
            label: Text('Finalizadas'),
            icon: Icon(Icons.check_circle_outline, size: 18),
          ),
        ],
        selected: {_filtro},
        onSelectionChanged: (s) => setState(() => _filtro = s.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: const Text('Mis pedidos'),
      actions: [
        if (!ApiConfig.effectiveMockData)
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(_refreshApi),
          ),
      ],
    );

    if (ApiConfig.effectiveMockData) {
      return ListenableBuilder(
        listenable: MockDataStore.instance,
        builder: (context, _) {
          final source = MockDataStore.instance.solicitudesDeCliente(widget.clienteId);
          return Scaffold(
            appBar: appBar,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filtroBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _onRefreshMock,
                    child: _list(source),
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
          _filtroBar(),
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
                          Text('Error: ${snap.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: () => setState(_refreshApi), child: const Text('Reintentar')),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _onRefreshApi,
                  child: _list(snap.data ?? []),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
