/// Tabla `pago` + enums del backend.
enum MetodoPago {
  qr('QR'),
  tarjeta('TARJETA'),
  efectivo('EFECTIVO');

  const MetodoPago(this.valorApi);
  final String valorApi;
}

enum EstadoPago {
  pendiente('PENDIENTE'),
  completado('COMPLETADO'),
  fallido('FALLIDO');

  const EstadoPago(this.valorApi);
  final String valorApi;

  static EstadoPago desdeString(String s) => EstadoPago.values.firstWhere(
        (e) => e.valorApi == s,
        orElse: () => EstadoPago.pendiente,
      );
}

class Pago {
  const Pago({
    required this.id,
    required this.solicitudId,
    required this.monto,
    required this.metodoPago,
    required this.estadoPago,
    required this.fechaPago,
  });

  final int id;
  final int solicitudId;
  final double monto;
  final MetodoPago metodoPago;
  final EstadoPago estadoPago;
  final DateTime fechaPago;

  factory Pago.fromJson(Map<String, dynamic> json) {
    return Pago(
      id: json['id'] as int,
      solicitudId: (json['solicitud_id'] ?? json['solicitudId']) as int,
      monto: (json['monto'] as num).toDouble(),
      metodoPago: MetodoPago.values.firstWhere(
        (e) => e.valorApi == json['metodo_pago'],
        orElse: () => MetodoPago.qr,
      ),
      estadoPago: EstadoPago.desdeString(json['estado_pago'] as String),
      fechaPago: DateTime.parse(json['fecha_pago'] as String),
    );
  }
}
