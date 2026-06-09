import 'package:flutter/material.dart';

import '../../models/solicitud_auxilio.dart';
import 'cliente_estilos_solicitud.dart';

/// Línea de tiempo del flujo (similar a apps de delivery / asistencia).
class SolicitudEstadoTimeline extends StatelessWidget {
  const SolicitudEstadoTimeline({
    super.key,
    required this.estadoActual,
    this.iaClasifico = false,
  });

  final EstadoSolicitud estadoActual;
  final bool iaClasifico;

  static const _orden = <EstadoSolicitud>[
    EstadoSolicitud.pendiente,
    EstadoSolicitud.clasificado,
    EstadoSolicitud.publicado,
    EstadoSolicitud.asignado,
    EstadoSolicitud.enCamino,
    EstadoSolicitud.enSitio,
    EstadoSolicitud.finalizado,
  ];

  @override
  Widget build(BuildContext context) {
    if (estadoActual == EstadoSolicitud.cancelado) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.cancel_outlined, color: Theme.of(context).colorScheme.error),
          title: const Text('Solicitud cancelada'),
          subtitle: const Text('Este pedido no continuará el flujo normal.'),
        ),
      );
    }

    final idxActual = _orden.indexOf(estadoActual);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Estado del servicio',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < _orden.length; i++)
              _PasoTimeline(
                titulo: etiquetaEstadoBreve(_orden[i]),
                subtitulo: _orden[i].valorApi,
                completado: _pasoCompletado(i, idxActual),
                esUltimo: i == _orden.length - 1,
                scheme: scheme,
              ),
          ],
        ),
      ),
    );
  }

  bool _pasoCompletado(int pasoIdx, int idxActual) {
    // Si ya llegó a un estado posterior, el flujo normal marca los pasos previos.
    if (idxActual >= 0 && pasoIdx <= idxActual) return true;
    // En algunos despliegues la IA setea tipo_servicio sin pasar explícitamente por CLASIFICADO.
    final idxClasificado = _orden.indexOf(EstadoSolicitud.clasificado);
    if (iaClasifico && pasoIdx == idxClasificado) return true;
    return false;
  }
}

class _PasoTimeline extends StatelessWidget {
  const _PasoTimeline({
    required this.titulo,
    required this.subtitulo,
    required this.completado,
    required this.esUltimo,
    required this.scheme,
  });

  final String titulo;
  final String subtitulo;
  final bool completado;
  final bool esUltimo;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completado ? scheme.primary : scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: completado ? scheme.primary : scheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: completado
                      ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                      : null,
                ),
                if (!esUltimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: completado
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: completado ? FontWeight.w600 : FontWeight.normal,
                          color: completado ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    subtitulo,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
