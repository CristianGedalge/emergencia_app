/// Coincide con [TallerResponse] del backend (FastAPI).
class Taller {
  const Taller({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.telefono,
    this.latitud,
    this.longitud,
  });

  final int id;
  final String nombre;
  final String direccion;
  final String? telefono;
  final double? latitud;
  final double? longitud;

  bool get tieneUbicacion =>
      latitud != null && longitud != null && latitud != 0 && longitud != 0;

  factory Taller.fromJson(Map<String, dynamic> json) {
    return Taller(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String,
      telefono: json['telefono'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
    );
  }
}
