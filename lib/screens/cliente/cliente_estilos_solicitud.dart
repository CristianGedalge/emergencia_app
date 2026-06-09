import 'package:flutter/material.dart';

import '../../models/solicitud_auxilio.dart';

Color colorPorEstadoSolicitud(EstadoSolicitud e, ColorScheme scheme) {
  switch (e) {
    case EstadoSolicitud.pendiente:
    case EstadoSolicitud.clasificado:
    case EstadoSolicitud.publicado:
    case EstadoSolicitud.aceptado:
      return scheme.tertiary;
    case EstadoSolicitud.asignado:
      return scheme.primary;
    case EstadoSolicitud.enCamino:
      return scheme.secondary;
    case EstadoSolicitud.enSitio:
      return Colors.teal.shade600;
    case EstadoSolicitud.finalizado:
      return scheme.outline;
    case EstadoSolicitud.cancelado:
      return scheme.error;
  }
}

String etiquetaEstadoBreve(EstadoSolicitud e) {
  switch (e) {
    case EstadoSolicitud.pendiente:
      return 'Buscando taller';
    case EstadoSolicitud.clasificado:
      return 'Clasificando';
    case EstadoSolicitud.publicado:
      return 'Enviada a talleres';
    case EstadoSolicitud.aceptado:
      return 'Taller aceptó';
    case EstadoSolicitud.asignado:
      return 'Taller asignado';
    case EstadoSolicitud.enCamino:
      return 'Mecánico en camino';
    case EstadoSolicitud.enSitio:
      return 'En el lugar';
    case EstadoSolicitud.finalizado:
      return 'Finalizada';
    case EstadoSolicitud.cancelado:
      return 'Cancelada';
  }
}

final Set<int> pagosLocalesCompletados = {};

bool solicitudSigueAbierta(SolicitudAuxilio s) {
  if (s.estado == EstadoSolicitud.cancelado) return false;
  if (s.estado == EstadoSolicitud.finalizado) {
    if (s.estadoPago == 'COMPLETADO') return false;
    return !pagosLocalesCompletados.contains(s.id);
  }
  return true;
}
