/// Calificación del cliente al servicio (post finalización). Demo MOCK.
class CalificacionServicio {
  const CalificacionServicio({
    required this.solicitudId,
    required this.clienteId,
    required this.estrellas,
    this.comentario,
    required this.fecha,
  });

  final int solicitudId;
  final int clienteId;
  final int estrellas;
  final String? comentario;
  final DateTime fecha;
}
