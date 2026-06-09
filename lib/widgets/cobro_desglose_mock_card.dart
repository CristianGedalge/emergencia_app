import 'package:flutter/material.dart';

import '../mock/mock_data_store.dart';
import '../models/solicitud_auxilio.dart';
import '../utils/tarifa_auxilio.dart';

/// Desglose: trayecto (tarifa demo) + extras del mecánico + total sugerido. Se actualiza con [MockDataStore].
class CobroDesgloseMockCard extends StatelessWidget {
  const CobroDesgloseMockCard({
    super.key,
    required this.solicitud,
    this.subtitulo,
    this.onEliminarLinea,
  });

  final SolicitudAuxilio solicitud;
  final String? subtitulo;

  /// Si no es null, cada línea extra muestra botón eliminar (solo antes de registrar pago).
  final void Function(int lineaId)? onEliminarLinea;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MockDataStore.instance,
      builder: (context, _) {
        final store = MockDataStore.instance;
        final km = store.kilometrosRutaAuxilio(solicitud);
        final base = TarifaAuxilio.montoSugerido(km);
        final extras = store.lineasExtraCobro(solicitud.id);
        final sumaExtras = store.sumaExtrasCobro(solicitud.id);
        final total = store.montoTotalSugeridoCobro(solicitud);
        final scheme = Theme.of(context).colorScheme;

        return Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resumen de cobro',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitulo!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 12),
                _fila(context, 'Auxilio / trayecto (${km.toStringAsFixed(2)} km)', base),
                if (extras.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sin cargos extra por reparación o repuestos todavía.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Text('Trabajo / repuestos', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  ...extras.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (onEliminarLinea != null)
                            IconButton(
                              tooltip: 'Quitar línea',
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => onEliminarLinea!(e.id),
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(foregroundColor: scheme.error),
                            ),
                          Expanded(child: Text(e.concepto, style: Theme.of(context).textTheme.bodyMedium)),
                          Text(
                            '${e.monto.toStringAsFixed(2)} Bs',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (sumaExtras > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _fila(context, 'Subtotal extras', sumaExtras, secundario: true),
                    ),
                ],
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total sugerido',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} Bs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _fila(BuildContext context, String label, double monto, {bool secundario = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: secundario
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          '${monto.toStringAsFixed(2)} Bs',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: secundario ? FontWeight.w500 : FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
