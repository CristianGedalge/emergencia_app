/// Tabla `vehiculo` (PostgreSQL / SQLAlchemy).
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.clienteId,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.placa,
    this.color,
    required this.estado,
    required this.fechaCreacion,
  });

  final int id;
  final int clienteId;
  final String marca;
  final String modelo;
  final int anio;
  final String placa;
  final String? color;
  final bool estado;
  final DateTime fechaCreacion;

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: (json['id'] as num).toInt(),
      clienteId: ((json['cliente_id'] ?? json['clienteId']) as num).toInt(),
      marca: json['marca'] as String,
      modelo: json['modelo'] as String,
      anio: (json['anio'] as num).toInt(),
      placa: json['placa'] as String,
      color: json['color'] as String?,
      estado: json['estado'] as bool? ?? true,
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'placa': placa,
        'color': color,
        'estado': estado,
        'fecha_creacion': fechaCreacion.toIso8601String(),
      };
}
