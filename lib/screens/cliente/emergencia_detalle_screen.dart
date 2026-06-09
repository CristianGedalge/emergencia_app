import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/pago.dart';
import '../../models/solicitud_auxilio.dart';
import '../../repositories/solicitudes_repository.dart';
import '../../repositories/vehiculos_repository.dart';
import '../../services/api_service.dart';
import '../../utils/tarifa_auxilio.dart';
import '../../widgets/cobro_desglose_mock_card.dart';
import 'solicitud_estado_timeline.dart';

bool _muestraSeguimientoClienteMecanico(SolicitudAuxilioVm vm) {
  if (vm.mecanicoId == null) return false;
  final e = vm.solicitud.estado;
  return e == EstadoSolicitud.asignado ||
      e == EstadoSolicitud.enCamino ||
      e == EstadoSolicitud.enSitio;
}

class EmergenciaDetalleScreen extends StatefulWidget {
  const EmergenciaDetalleScreen({
    super.key,
    required this.clienteId,
    required this.solicitudId,
  });

  final int clienteId;
  final int solicitudId;

  @override
  State<EmergenciaDetalleScreen> createState() => _EmergenciaDetalleScreenState();
}

class _EmergenciaDetalleScreenState extends State<EmergenciaDetalleScreen> {
  Future<SolicitudAuxilioVm?>? _futureApiDetalle;
  Timer? _pollEstado;

  @override
  void initState() {
    super.initState();
    if (!ApiConfig.effectiveMockData) {
      _futureApiDetalle = solicitudesRepository().obtener(widget.solicitudId, widget.clienteId);
      _pollEstado = Timer.periodic(const Duration(seconds: 8), (_) {
        if (mounted) _refreshApiDetalle();
      });
    }
  }

  void _refreshApiDetalle() {
    if (!ApiConfig.effectiveMockData) {
      setState(() {
        _futureApiDetalle = solicitudesRepository().obtener(widget.solicitudId, widget.clienteId);
      });
    }
  }

  @override
  void dispose() {
    _pollEstado?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ApiConfig.effectiveMockData) {
      return ListenableBuilder(
        listenable: MockDataStore.instance,
        builder: (context, _) {
          final vm = MockDataStore.instance.solicitudVm(widget.solicitudId, widget.clienteId);
          if (vm == null) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Solicitud'),
                leading: const BackButton(),
              ),
              body: const Center(child: Text('No encontrada')),
            );
          }
          final s = vm.solicitud;
          return Scaffold(
            appBar: AppBar(
              title: Text('Solicitud #${s.id}'),
              leading: const BackButton(),
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey<Object>(
                  '${s.id}-${s.estado.name}-${MockDataStore.instance.pagoDeSolicitud(s.id)?.estadoPago.name ?? 'sinpago'}-${MockDataStore.instance.firmaExtrasCobro(s.id)}-${MockDataStore.instance.calificacionDeSolicitud(s.id)?.estrellas ?? 0}',
                ),
                child: _DetalleBody(vm: vm),
              ),
            ),
          );
        },
      );
    }

    return FutureBuilder<SolicitudAuxilioVm?>(
      future: _futureApiDetalle,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              actions: [
                IconButton(
                  tooltip: 'Actualizar estado',
                  onPressed: _refreshApiDetalle,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final vm = snap.data;
        if (vm == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Solicitud'),
              leading: const BackButton(),
            ),
            body: const Center(child: Text('No encontrada o sin API.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Solicitud #${vm.solicitud.id}'),
            leading: const BackButton(),
            actions: [
              IconButton(
                tooltip: 'Actualizar estado',
                onPressed: _refreshApiDetalle,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _DetalleBody(vm: vm),
        );
      },
    );
  }
}

class _DetalleBody extends StatelessWidget {
  const _DetalleBody({required this.vm});

  final SolicitudAuxilioVm vm;

  Future<({String? placa, String? tipoServicioNombre})> _cargarMeta() async {
    final s = vm.solicitud;
    String? placa = s.vehiculoPlaca;
    String? tipoServicioNombre = s.tipoServicioNombre;

    if (placa == null || placa.trim().isEmpty) {
      try {
        final v = await vehiculosRepository().obtener(s.vehiculoId, s.clienteId);
        placa = v?.placa;
      } catch (_) {}
    }

    if ((tipoServicioNombre == null || tipoServicioNombre.trim().isEmpty) &&
        s.tipoServicioId != null) {
      try {
        tipoServicioNombre = await ApiService.instance.fetchNombreTipoServicio(s.tipoServicioId!);
      } catch (_) {}
    }

    return (placa: placa, tipoServicioNombre: tipoServicioNombre);
  }

  Future<void> _avanzarDemo(BuildContext context) async {
    HapticFeedback.selectionClick();
    solicitudesRepository().demoAvanzarEstado(vm.solicitud.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado actualizado (simulación)')),
      );
    }
  }

  Future<void> _registrarPagoDialog(BuildContext context) async {
    double? montoInicial;
    if (ApiConfig.effectiveMockData) {
      montoInicial = MockDataStore.instance.montoTotalSugeridoCobro(vm.solicitud);
    }
    final r = await showDialog<({double monto, MetodoPago metodo})>(
      context: context,
      builder: (c) => _PagoFormDialog(montoInicial: montoInicial),
    );
    if (r == null || !context.mounted) return;
    await solicitudesRepository().registrarPago(
      solicitudId: vm.solicitud.id,
      monto: r.monto,
      metodo: r.metodo,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago registrado')));
    }
  }

  Future<void> _completarPago(BuildContext context) async {
    await solicitudesRepository().completarPago(vm.solicitud.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago completado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = vm.solicitud;
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Marca "Clasificado" cuando ya existe tipo de servicio asignado por IA.
          // Esto evita que el timeline quede visualmente atrasado en despliegues
          // donde el backend salta de PENDIENTE directamente a PUBLICADO.
          SolicitudEstadoTimeline(
            estadoActual: s.estado,
            iaClasifico: s.tipoServicioId != null,
          ),
          const SizedBox(height: 16),
          FutureBuilder<({String? placa, String? tipoServicioNombre})>(
            future: _cargarMeta(),
            builder: (context, snap) {
              final data = snap.data;
              final placa = data?.placa;
              final tipo = data?.tipoServicioNombre;
              return Column(
                children: [
                  ListTile(
                    title: const Text('Vehículo'),
                    subtitle: Text(
                      placa == null || placa.trim().isEmpty
                          ? 'Sin placa disponible'
                          : 'Placa: ${placa.trim()}',
                    ),
                  ),
                  ListTile(
                    title: const Text('Tipo de servicio'),
                    subtitle: Text(
                      tipo != null && tipo.trim().isNotEmpty
                          ? tipo.trim()
                          : (s.tipoServicioId != null
                              ? 'Servicio #${s.tipoServicioId}'
                              : 'Pendiente de clasificación'),
                    ),
                  ),
                ],
              );
            },
          ),
          if (s.descripcion != null && s.descripcion!.isNotEmpty)
            ListTile(
              title: const Text('Descripción del problema'),
              subtitle: Text(s.descripcion!),
            ),
          if (vm.tallerNombreAsignado != null)
            ListTile(
              title: const Text('Taller asignado'),
              subtitle: Text(
                '${vm.tallerNombreAsignado} (tabla asignacion_auxilio en servidor)',
              ),
            ),
          if (vm.mecanicoId != null)
            ListTile(
              title: const Text('Mecánico asignado'),
              subtitle: Text('ID #${vm.mecanicoId}'),
            ),
          if (_muestraSeguimientoClienteMecanico(vm))
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.route),
                title: const Text('Seguimiento en vivo'),
                subtitle: Text(
                  'En la barra inferior, pestaña Seguimiento: tu ubicación, el punto del auxilio y el mecánico en marcha. '
                  'En MOCK la posición del mecánico se simula; en producción sería GPS del móvil del mecánico y un canal en tiempo real.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (ApiConfig.effectiveMockData) ...[
            const SizedBox(height: 8),
            CobroDesgloseMockCard(
              solicitud: s,
              subtitulo:
                  'El mecánico puede sumar reparación o repuestos; este resumen se actualiza al instante.',
            ),
          ],
          const Divider(),
          if (ApiConfig.effectiveMockData) ...[
            FilledButton.tonal(
              onPressed: () => _avanzarDemo(context),
              child: const Text('Avanzar estado (simulación)'),
            ),
            const SizedBox(height: 8),
            Text(
              'En producción el backend y el taller actualizan el estado; esto es solo para ver el flujo en el parcial.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text('Pago', style: Theme.of(context).textTheme.titleMedium),
          if (ApiConfig.effectiveMockData)
            ListenableBuilder(
              listenable: MockDataStore.instance,
              builder: (context, _) {
                final p = MockDataStore.instance.pagoDeSolicitud(s.id);
                if (p == null) {
                  return OutlinedButton.icon(
                    onPressed: () => _registrarPagoDialog(context),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Registrar pago (demo)'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: Icon(
                          p.estadoPago == EstadoPago.completado
                              ? Icons.verified_rounded
                              : Icons.schedule_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text('${p.monto} Bs · ${p.metodoPago.valorApi}'),
                        subtitle: Text('Estado pago: ${p.estadoPago.valorApi}'),
                      ),
                    ),
                    if (p.estadoPago == EstadoPago.pendiente)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _completarPago(context);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar pago recibido (demo)'),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            FutureBuilder<Pago?>(
              future: solicitudesRepository().pagoDeSolicitud(s.id),
              builder: (context, snap) {
                final p = snap.data;
                if (p == null) {
                  return const Text('Sin datos de pago (API no conectada).');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('monto / metodo_pago / estado_pago'),
                      subtitle: Text(
                        '${p.monto} · ${p.metodoPago.valorApi} · ${p.estadoPago.valorApi}',
                      ),
                    ),
                  ],
                );
              },
            ),
          if (ApiConfig.effectiveMockData && s.estado == EstadoSolicitud.finalizado) ...[
            const Divider(height: 32),
            Text('Calificá el servicio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: MockDataStore.instance,
              builder: (context, _) {
                final cal = MockDataStore.instance.calificacionDeSolicitud(s.id);
                if (cal != null) {
                  return Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      leading: Icon(Icons.star_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
                      title: Text('Tu calificación: ${cal.estrellas} de 5'),
                      subtitle: cal.comentario != null && cal.comentario!.isNotEmpty
                          ? Text(cal.comentario!)
                          : const Text('Gracias por valorar el servicio.'),
                    ),
                  );
                }
                return _CalificaServicioForm(clienteId: s.clienteId, solicitudId: s.id);
              },
            ),
          ],
        ],
      );
  }
}

class _CalificaServicioForm extends StatefulWidget {
  const _CalificaServicioForm({required this.clienteId, required this.solicitudId});

  final int clienteId;
  final int solicitudId;

  @override
  State<_CalificaServicioForm> createState() => _CalificaServicioFormState();
}

class _CalificaServicioFormState extends State<_CalificaServicioForm> {
  int _estrellas = 5;
  final _comentario = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Cómo fue la atención?', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final n = i + 1;
            return IconButton(
              tooltip: '$n estrella${n == 1 ? '' : 's'}',
              iconSize: 40,
              onPressed: _busy ? null : () => setState(() => _estrellas = n),
              icon: Icon(
                n <= _estrellas ? Icons.star_rounded : Icons.star_border_rounded,
                color: n <= _estrellas ? scheme.primary : scheme.outline,
              ),
            );
          }),
        ),
        TextField(
          controller: _comentario,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await solicitudesRepository().registrarCalificacion(
                      solicitudId: widget.solicitudId,
                      clienteId: widget.clienteId,
                      estrellas: _estrellas,
                      comentario: _comentario.text,
                    );
                    if (context.mounted) {
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('¡Gracias por tu calificación!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: _busy
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar calificación'),
        ),
      ],
    );
  }
}

class _PagoFormDialog extends StatefulWidget {
  const _PagoFormDialog({this.montoInicial});

  /// Monto sugerido por distancia (mock) o null para usar mínimo demo.
  final double? montoInicial;

  @override
  State<_PagoFormDialog> createState() => _PagoFormDialogState();
}

class _PagoFormDialogState extends State<_PagoFormDialog> {
  late final TextEditingController _monto = TextEditingController(
    text: (widget.montoInicial != null && widget.montoInicial! > 0)
        ? widget.montoInicial!.toStringAsFixed(2)
        : TarifaAuxilio.minimoBs.toStringAsFixed(2),
  );
  MetodoPago _metodo = MetodoPago.qr;

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pago'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _monto,
              decoration: const InputDecoration(
                labelText: 'Monto (Bs.)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            Text('Método', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MetodoPago>(
              segments: const [
                ButtonSegment(
                  value: MetodoPago.efectivo,
                  label: Text('Efectivo'),
                  icon: Icon(Icons.payments_outlined, size: 18),
                ),
                ButtonSegment(
                  value: MetodoPago.qr,
                  label: Text('QR'),
                  icon: Icon(Icons.qr_code_2_outlined, size: 18),
                ),
              ],
              selected: {_metodo},
              onSelectionChanged: (s) => setState(() => _metodo = s.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final monto = double.tryParse(_monto.text.replaceAll(',', '.'));
            if (monto == null || monto <= 0) return;
            Navigator.pop(context, (monto: monto, metodo: _metodo));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
