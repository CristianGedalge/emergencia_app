/// Tabla `solicitud_auxilio` + enum `EstadoSolicitudEnum`.
enum EstadoSolicitud {
  pendiente('PENDIENTE'),
  clasificado('CLASIFICADO'),
  publicado('PUBLICADO'),
  aceptado('ACEPTADO'),
  asignado('ASIGNADO'),
  enCamino('EN_CAMINO'),
  enSitio('EN_SITIO'),
  finalizado('FINALIZADO'),
  cancelado('CANCELADO');

  const EstadoSolicitud(this.valorApi);
  final String valorApi;

  static EstadoSolicitud desdeString(String s) {
    return EstadoSolicitud.values.firstWhere(
      (e) => e.valorApi == s,
      orElse: () => EstadoSolicitud.pendiente,
    );
  }
}

class SolicitudAuxilio {
  const SolicitudAuxilio({
    required this.id,
    required this.clienteId,
    required this.vehiculoId,
    this.tipoServicioId,
    this.tipoServicioNombre,
    this.vehiculoPlaca,
    this.descripcion,
    this.urlImg,
    this.urlAudio,
    required this.latitud,
    required this.longitud,
    required this.estado,
    required this.fechaCreacion,
    this.estadoPago,
  });

  final int id;
  final int clienteId;
  final int vehiculoId;
  final int? tipoServicioId;
  final String? tipoServicioNombre;
  final String? vehiculoPlaca;
  final String? descripcion;
  final String? urlImg;
  final String? urlAudio;
  final double latitud;
  final double longitud;
  final EstadoSolicitud estado;
  final DateTime fechaCreacion;
  final String? estadoPago;

  factory SolicitudAuxilio.fromJson(Map<String, dynamic> json) {
    final fotos = json['urls_fotos'];
    String? primeraFoto;
    if (fotos is List && fotos.isNotEmpty) {
      final f0 = fotos.first;
      if (f0 is String) primeraFoto = f0;
    }
    return SolicitudAuxilio(
      id: json['id'] as int,
      clienteId: (json['cliente_id'] ?? json['clienteId']) as int,
      vehiculoId: (json['vehiculo_id'] ?? json['vehiculoId']) as int,
      tipoServicioId: json['tipo_servicio_id'] as int?,
      tipoServicioNombre: (json['tipo_servicio_nombre'] ??
              json['tipoServicioNombre'] ??
              json['nombre_tipo_servicio'] ??
              json['nombre_servicio']) as String?,
      vehiculoPlaca:
          (json['vehiculo_placa'] ??
              json['vehiculoPlaca'] ??
              json['placa_vehiculo'] ??
              json['placa']) as String?,
      descripcion: json['descripcion'] as String?,
      urlImg: (json['url_img'] as String?) ?? primeraFoto,
      urlAudio: json['url_audio'] as String?,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      estado: EstadoSolicitud.desdeString(json['estado'] as String),
      fechaCreacion: DateTime.parse(json['fecha_creacion'] as String),
      estadoPago: json['estado_pago'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'vehiculo_id': vehiculoId,
        'tipo_servicio_id': tipoServicioId,
        'tipo_servicio_nombre': tipoServicioNombre,
        'vehiculo_placa': vehiculoPlaca,
        'descripcion': descripcion,
        'url_img': urlImg,
        'url_audio': urlAudio,
        'latitud': latitud,
        'longitud': longitud,
        'estado': estado.valorApi,
        'fecha_creacion': fechaCreacion.toIso8601String(),
        'estado_pago': estadoPago,
      };

  SolicitudAuxilio copyWith({
    int? tipoServicioId,
    String? tipoServicioNombre,
    String? vehiculoPlaca,
    String? descripcion,
    String? urlImg,
    String? urlAudio,
    double? latitud,
    double? longitud,
    EstadoSolicitud? estado,
    DateTime? fechaCreacion,
    String? estadoPago,
  }) {
    return SolicitudAuxilio(
      id: id,
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      tipoServicioId: tipoServicioId ?? this.tipoServicioId,
      tipoServicioNombre: tipoServicioNombre ?? this.tipoServicioNombre,
      vehiculoPlaca: vehiculoPlaca ?? this.vehiculoPlaca,
      descripcion: descripcion ?? this.descripcion,
      urlImg: urlImg ?? this.urlImg,
      urlAudio: urlAudio ?? this.urlAudio,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      estadoPago: estadoPago ?? this.estadoPago,
    );
  }
}

/// Datos extra de presentación (en el servidor vendrían de un JOIN, no son columnas de `solicitud_auxilio`).
class SolicitudAuxilioVm {
  const SolicitudAuxilioVm({
    required this.solicitud,
    this.tallerNombreAsignado,
    this.tallerId,
    this.mecanicoId,
    this.mecanicoNombre,
    this.mecanicoTelefono,
    this.clienteNombre,
    /// `usuario.telefono` del cliente (API / JOIN). Null si no cargó número.
    this.clienteTelefono,
  });

  final SolicitudAuxilio solicitud;
  final String? tallerNombreAsignado;
  final int? tallerId;
  final int? mecanicoId;
  final String? mecanicoNombre;
  final String? mecanicoTelefono;
  final String? clienteNombre;
  final String? clienteTelefono;
}
