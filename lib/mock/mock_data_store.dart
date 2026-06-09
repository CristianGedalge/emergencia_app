import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/calificacion_servicio.dart';
import '../models/cobro_extra_linea.dart';
import '../models/pago.dart';
import '../models/solicitud_auxilio.dart';
import '../models/taller.dart';
import '../models/vehiculo.dart';
import '../utils/geo.dart';
import '../utils/tarifa_auxilio.dart';

/// Asignación en BD: `asignacion_auxilio` (solicitud_id, taller_id, mecanico_id).
class AsignacionAuxilioMock {
  const AsignacionAuxilioMock({
    required this.solicitudId,
    required this.tallerId,
    required this.mecanicoId,
    required this.tallerNombre,
  });

  final int solicitudId;
  final int tallerId;
  final int mecanicoId;
  final String tallerNombre;
}

/// Datos de demostración alineados a tablas reales (sin campos inventados).
class MockDataStore extends ChangeNotifier {
  MockDataStore._();
  static final MockDataStore instance = MockDataStore._();

  bool _seeded = false;
  int _nextVehiculoId = 1000;
  int _nextSolicitudId = 2000;
  int _nextPagoId = 3000;
  int _nextExtraLineaId = 4000;

  final List<Taller> _talleres = [];
  final List<Vehiculo> _vehiculos = [];
  final List<SolicitudAuxilio> _solicitudes = [];
  final Map<int, AsignacionAuxilioMock> _asignacionesPorSolicitud = {};
  final Map<int, Pago> _pagosPorSolicitud = {};
  final Map<int, List<CobroExtraLinea>> _extrasCobroPorSolicitud = {};
  final Map<int, CalificacionServicio> _calificacionesPorSolicitud = {};

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final ahora = DateTime.now().toUtc();

    _talleres.addAll([
      Taller(
        id: 1,
        nombre: 'Taller Demo Centro',
        direccion: 'Av. Monseñor Rivero 100, Santa Cruz',
        telefono: '33445566',
        latitud: -17.7835,
        longitud: -63.1821,
      ),
      Taller(
        id: 2,
        nombre: 'Taller Demo Equipetrol',
        direccion: '4to Anillo Equipetrol, Santa Cruz',
        telefono: null,
        latitud: -17.7612,
        longitud: -63.1954,
      ),
    ]);

    _vehiculos.addAll([
      Vehiculo(
        id: 101,
        clienteId: 1,
        marca: 'Toyota',
        modelo: 'Corolla',
        anio: 2019,
        placa: 'ABC123',
        color: 'Plata',
        estado: true,
        fechaCreacion: ahora,
      ),
      Vehiculo(
        id: 102,
        clienteId: 1,
        marca: 'Suzuki',
        modelo: 'Swift',
        anio: 2021,
        placa: 'XYZ789',
        color: null,
        estado: true,
        fechaCreacion: ahora,
      ),
    ]);

    _solicitudes.add(
      SolicitudAuxilio(
        id: 201,
        clienteId: 1,
        vehiculoId: 101,
        tipoServicioId: null,
        descripcion: 'La batería no da arranque; tablero sin luces.',
        urlImg: null,
        urlAudio: null,
        latitud: -17.784,
        longitud: -63.181,
        estado: EstadoSolicitud.asignado,
        fechaCreacion: ahora,
      ),
    );
    _asignacionesPorSolicitud[201] = const AsignacionAuxilioMock(
      solicitudId: 201,
      tallerId: 1,
      mecanicoId: 501,
      tallerNombre: 'Taller Demo Centro',
    );

    _solicitudes.add(
      SolicitudAuxilio(
        id: 202,
        clienteId: 1,
        vehiculoId: 102,
        tipoServicioId: null,
        descripcion: 'Auxilio en ruta — llanta cámara.',
        urlImg: null,
        urlAudio: null,
        latitud: -17.770,
        longitud: -63.190,
        estado: EstadoSolicitud.enCamino,
        fechaCreacion: ahora,
      ),
    );
    _asignacionesPorSolicitud[202] = const AsignacionAuxilioMock(
      solicitudId: 202,
      tallerId: 1,
      mecanicoId: 501,
      tallerNombre: 'Taller Demo Centro',
    );
  }

  void ensureSeed() => _seed();

  static int _pesoSeguimiento(EstadoSolicitud e) {
    switch (e) {
      case EstadoSolicitud.enCamino:
        return 0;
      case EstadoSolicitud.asignado:
        return 1;
      case EstadoSolicitud.enSitio:
        return 2;
      default:
        return 99;
    }
  }

  /// Caso activo con mecánico asignado (cliente ve mapa de seguimiento).
  SolicitudAuxilioVm? solicitudSeguimientoPrioritariaCliente(int clienteId) {
    _seed();
    final list = solicitudesDeCliente(clienteId).where((vm) {
      if (vm.mecanicoId == null) return false;
      final e = vm.solicitud.estado;
      return e == EstadoSolicitud.asignado ||
          e == EstadoSolicitud.enCamino ||
          e == EstadoSolicitud.enSitio;
    }).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) {
      final wa = _pesoSeguimiento(a.solicitud.estado);
      final wb = _pesoSeguimiento(b.solicitud.estado);
      if (wa != wb) return wa.compareTo(wb);
      return b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion);
    });
    return list.first;
  }

  /// Caso activo que el mecánico debe cubrir en mapa (misma prioridad que cliente).
  SolicitudAuxilioVm? solicitudSeguimientoPrioritariaMecanico(int mecanicoId) {
    _seed();
    final list = ordenesParaMecanico(mecanicoId).where((vm) {
      final e = vm.solicitud.estado;
      return e == EstadoSolicitud.asignado ||
          e == EstadoSolicitud.enCamino ||
          e == EstadoSolicitud.enSitio;
    }).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) {
      final wa = _pesoSeguimiento(a.solicitud.estado);
      final wb = _pesoSeguimiento(b.solicitud.estado);
      if (wa != wb) return wa.compareTo(wb);
      return b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion);
    });
    return list.first;
  }

  /// Posición del mecánico hacia el incidente: misma fórmula en cliente y app mecánico (demo hasta WebSocket/GPS real).
  LatLng posicionMecanicoSimulada(SolicitudAuxilio s) {
    _seed();
    final dest = LatLng(s.latitud, s.longitud);
    if (s.estado == EstadoSolicitud.enSitio ||
        s.estado == EstadoSolicitud.finalizado ||
        s.estado == EstadoSolicitud.cancelado) {
      return dest;
    }
    if (s.estado == EstadoSolicitud.pendiente ||
        s.estado == EstadoSolicitud.clasificado ||
        s.estado == EstadoSolicitud.publicado) {
      return LatLng(dest.latitude + 0.022, dest.longitude + 0.016);
    }
    final start = LatLng(dest.latitude + 0.018, dest.longitude + 0.014);
    final ms = DateTime.now().millisecondsSinceEpoch;
    const cycleMs = 42000;
    final t = ((ms % cycleMs) / cycleMs).clamp(0.0, 1.0);
    return LatLng(
      start.latitude + (dest.latitude - start.latitude) * t,
      start.longitude + (dest.longitude - start.longitude) * t,
    );
  }

  /// Kilómetros de ida (origen simulado del móvil → incidente), alineado a [posicionMecanicoSimulada]. Sirve para cobro por trayecto.
  double kilometrosRutaAuxilio(SolicitudAuxilio s) {
    _seed();
    final dest = LatLng(s.latitud, s.longitud);
    if (s.estado == EstadoSolicitud.pendiente ||
        s.estado == EstadoSolicitud.clasificado ||
        s.estado == EstadoSolicitud.publicado ||
        s.estado == EstadoSolicitud.cancelado) {
      return 0;
    }
    final start = LatLng(dest.latitude + 0.018, dest.longitude + 0.014);
    return distanciaKm(start, dest) ?? 0;
  }

  SolicitudAuxilioVm? solicitudVmParaMecanico(int solicitudId, int mecanicoId) {
    _seed();
    for (final vm in ordenesParaMecanico(mecanicoId)) {
      if (vm.solicitud.id == solicitudId) return vm;
    }
    return null;
  }

  List<Taller> get talleres {
    _seed();
    return List.unmodifiable(_talleres);
  }

  List<Vehiculo> vehiculosActivosDeCliente(int clienteId) {
    _seed();
    return _vehiculos
        .where((v) => v.clienteId == clienteId && v.estado)
        .toList();
  }

  Future<Vehiculo> crearVehiculo({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) async {
    _seed();
    final existe = _vehiculos.any(
      (v) => v.placa.toUpperCase() == placa.toUpperCase() && v.estado,
    );
    if (existe) {
      throw StateError('Ya existe un vehículo activo con esa placa');
    }
    final v = Vehiculo(
      id: _nextVehiculoId++,
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa.toUpperCase(),
      color: color,
      estado: true,
      fechaCreacion: DateTime.now().toUtc(),
    );
    _vehiculos.add(v);
    notifyListeners();
    return v;
  }

  Future<Vehiculo?> actualizarVehiculo({
    required int id,
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) async {
    _seed();
    final i = _vehiculos.indexWhere((v) => v.id == id && v.clienteId == clienteId);
    if (i < 0) return null;
    final otro = _vehiculos.any(
      (v) =>
          v.id != id &&
          v.estado &&
          v.placa.toUpperCase() == placa.toUpperCase(),
    );
    if (otro) throw StateError('Otro vehículo ya usa esa placa');
    final prev = _vehiculos[i];
    _vehiculos[i] = Vehiculo(
      id: prev.id,
      clienteId: prev.clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa.toUpperCase(),
      color: color,
      estado: prev.estado,
      fechaCreacion: prev.fechaCreacion,
    );
    notifyListeners();
    return _vehiculos[i];
  }

  Future<bool> desactivarVehiculo(int id, int clienteId) async {
    _seed();
    final i = _vehiculos.indexWhere((v) => v.id == id && v.clienteId == clienteId);
    if (i < 0) return false;
    final v = _vehiculos[i];
    _vehiculos[i] = Vehiculo(
      id: v.id,
      clienteId: v.clienteId,
      marca: v.marca,
      modelo: v.modelo,
      anio: v.anio,
      placa: v.placa,
      color: v.color,
      estado: false,
      fechaCreacion: v.fechaCreacion,
    );
    notifyListeners();
    return true;
  }

  Vehiculo? vehiculoPorId(int id, int clienteId) {
    _seed();
    try {
      return _vehiculos.firstWhere((v) => v.id == id && v.clienteId == clienteId);
    } catch (_) {
      return null;
    }
  }

  /// Teléfono del cliente (demo = tabla `usuario`; en API vendría en el DTO de la orden).
  String? telefonoClienteDemo(int clienteId) {
    switch (clienteId) {
      case 1:
        return '70012345';
      default:
        return null;
    }
  }

  SolicitudAuxilioVm _vmDesdeSolicitud(SolicitudAuxilio s) {
    final a = _asignacionesPorSolicitud[s.id];
    return SolicitudAuxilioVm(
      solicitud: s,
      tallerNombreAsignado: a?.tallerNombre,
      mecanicoId: a?.mecanicoId,
      clienteTelefono: telefonoClienteDemo(s.clienteId),
    );
  }

  /// Para vista mecánico: vehículo de la solicitud (cualquier cliente).
  Vehiculo? vehiculoPorIdGlobal(int vehiculoId) {
    _seed();
    try {
      return _vehiculos.firstWhere((v) => v.id == vehiculoId);
    } catch (_) {
      return null;
    }
  }

  /// Órdenes donde `asignacion_auxilio.mecanico_id` coincide (mismo criterio que usaría el backend).
  List<SolicitudAuxilioVm> ordenesParaMecanico(int mecanicoId) {
    _seed();
    final out = <SolicitudAuxilioVm>[];
    for (final s in _solicitudes) {
      final a = _asignacionesPorSolicitud[s.id];
      if (a != null && a.mecanicoId == mecanicoId) {
        out.add(_vmDesdeSolicitud(s));
      }
    }
    out.sort((a, b) => b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion));
    return out;
  }

  List<SolicitudAuxilioVm> solicitudesDeCliente(int clienteId) {
    _seed();
    return _solicitudes
        .where((s) => s.clienteId == clienteId)
        .map(_vmDesdeSolicitud)
        .toList()
      ..sort((a, b) => b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion));
  }

  SolicitudAuxilioVm? solicitudVm(int id, int clienteId) {
    _seed();
    try {
      final s = _solicitudes.firstWhere((x) => x.id == id && x.clienteId == clienteId);
      return _vmDesdeSolicitud(s);
    } catch (_) {
      return null;
    }
  }

  Future<SolicitudAuxilioVm> crearSolicitud({
    required int clienteId,
    required int vehiculoId,
    String? descripcion,
    required double latitud,
    required double longitud,
    String? urlImg,
    String? urlAudio,
  }) async {
    _seed();
    final v = vehiculoPorId(vehiculoId, clienteId);
    if (v == null || !v.estado) {
      throw StateError('Vehículo inválido');
    }
    final s = SolicitudAuxilio(
      id: _nextSolicitudId++,
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      tipoServicioId: null,
      descripcion: descripcion,
      urlImg: urlImg,
      urlAudio: urlAudio,
      latitud: latitud,
      longitud: longitud,
      estado: EstadoSolicitud.pendiente,
      fechaCreacion: DateTime.now().toUtc(),
    );
    _solicitudes.add(s);
    notifyListeners();
    return _vmDesdeSolicitud(s);
  }

  /// Simula el pipeline hasta que exista taller asignado (como motor + web).
  void demoAvanzarEstado(int solicitudId) {
    _seed();
    final i = _solicitudes.indexWhere((s) => s.id == solicitudId);
    if (i < 0) return;
    final s = _solicitudes[i];
    if (s.estado == EstadoSolicitud.finalizado || s.estado == EstadoSolicitud.cancelado) {
      return;
    }
    const orden = <EstadoSolicitud>[
      EstadoSolicitud.pendiente,
      EstadoSolicitud.clasificado,
      EstadoSolicitud.publicado,
      EstadoSolicitud.asignado,
      EstadoSolicitud.enCamino,
      EstadoSolicitud.enSitio,
      EstadoSolicitud.finalizado,
    ];
    final idx = orden.indexOf(s.estado);
    if (idx < 0 || idx >= orden.length - 1) return;
    final next = orden[idx + 1];
    _solicitudes[i] = s.copyWith(estado: next);
    if (next == EstadoSolicitud.asignado) {
      _asignacionesPorSolicitud[solicitudId] = AsignacionAuxilioMock(
        solicitudId: solicitudId,
        tallerId: 1,
        mecanicoId: 501,
        tallerNombre: 'Taller Demo Centro',
      );
    }
    notifyListeners();
  }

  Pago? pagoDeSolicitud(int solicitudId) {
    _seed();
    return _pagosPorSolicitud[solicitudId];
  }

  /// Firma para [ValueKey] cuando cambian líneas extra.
  String firmaExtrasCobro(int solicitudId) {
    _seed();
    final list = _extrasCobroPorSolicitud[solicitudId] ?? const <CobroExtraLinea>[];
    if (list.isEmpty) return '0';
    return '${list.length}_${list.map((e) => '${e.id}:${e.monto.toStringAsFixed(2)}').join('|')}';
  }

  List<CobroExtraLinea> lineasExtraCobro(int solicitudId) {
    _seed();
    return List.unmodifiable(_extrasCobroPorSolicitud[solicitudId] ?? const <CobroExtraLinea>[]);
  }

  double sumaExtrasCobro(int solicitudId) {
    _seed();
    final list = _extrasCobroPorSolicitud[solicitudId] ?? const <CobroExtraLinea>[];
    return list.fold<double>(0, (a, e) => a + e.monto);
  }

  double montoBaseTrayecto(SolicitudAuxilio s) {
    return TarifaAuxilio.montoSugerido(kilometrosRutaAuxilio(s));
  }

  double montoTotalSugeridoCobro(SolicitudAuxilio s) {
    final t = montoBaseTrayecto(s) + sumaExtrasCobro(s.id);
    return double.parse(t.toStringAsFixed(2));
  }

  CalificacionServicio? calificacionDeSolicitud(int solicitudId) {
    _seed();
    return _calificacionesPorSolicitud[solicitudId];
  }

  /// Solo sin pago registrado aún (pendiente de cobro).
  void agregarLineaExtraCobro(
    int solicitudId, {
    required String concepto,
    required double monto,
  }) {
    _seed();
    if (_pagosPorSolicitud[solicitudId] != null) {
      throw StateError('Ya hay un pago registrado; no se pueden agregar líneas extra.');
    }
    final c = concepto.trim();
    if (c.isEmpty) throw ArgumentError('El concepto no puede estar vacío.');
    if (monto <= 0) throw ArgumentError('El monto debe ser mayor a cero.');
    final redondeado = double.parse(monto.toStringAsFixed(2));
    final linea = CobroExtraLinea(
      id: _nextExtraLineaId++,
      solicitudId: solicitudId,
      concepto: c,
      monto: redondeado,
    );
    _extrasCobroPorSolicitud.putIfAbsent(solicitudId, () => <CobroExtraLinea>[]).add(linea);
    notifyListeners();
  }

  bool eliminarLineaExtraCobro(int solicitudId, int lineaId) {
    _seed();
    if (_pagosPorSolicitud[solicitudId] != null) return false;
    final list = _extrasCobroPorSolicitud[solicitudId];
    if (list == null || list.isEmpty) return false;
    final antes = list.length;
    list.removeWhere((e) => e.id == lineaId);
    if (list.isEmpty) _extrasCobroPorSolicitud.remove(solicitudId);
    if (list.length != antes) {
      notifyListeners();
      return true;
    }
    return false;
  }

  void registrarCalificacion({
    required int solicitudId,
    required int clienteId,
    required int estrellas,
    String? comentario,
  }) {
    _seed();
    if (estrellas < 1 || estrellas > 5) {
      throw ArgumentError('Las estrellas deben estar entre 1 y 5.');
    }
    final vm = solicitudVm(solicitudId, clienteId);
    if (vm == null) throw StateError('Solicitud no encontrada para este cliente.');
    if (vm.solicitud.estado != EstadoSolicitud.finalizado) {
      throw StateError('Solo podés calificar cuando el servicio está finalizado.');
    }
    if (_calificacionesPorSolicitud.containsKey(solicitudId)) return;
    final com = comentario?.trim();
    _calificacionesPorSolicitud[solicitudId] = CalificacionServicio(
      solicitudId: solicitudId,
      clienteId: clienteId,
      estrellas: estrellas,
      comentario: (com == null || com.isEmpty) ? null : com,
      fecha: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  Future<Pago> crearOActualizarPago({
    required int solicitudId,
    required double monto,
    required MetodoPago metodo,
  }) async {
    _seed();
    final existente = _pagosPorSolicitud[solicitudId];
    final id = existente?.id ?? _nextPagoId++;
    final p = Pago(
      id: id,
      solicitudId: solicitudId,
      monto: monto,
      metodoPago: metodo,
      estadoPago: EstadoPago.pendiente,
      fechaPago: DateTime.now().toUtc(),
    );
    _pagosPorSolicitud[solicitudId] = p;
    notifyListeners();
    return p;
  }

  Future<Pago?> marcarPagoCompletado(int solicitudId) async {
    _seed();
    final p = _pagosPorSolicitud[solicitudId];
    if (p == null) return null;
    final nuevo = Pago(
      id: p.id,
      solicitudId: p.solicitudId,
      monto: p.monto,
      metodoPago: p.metodoPago,
      estadoPago: EstadoPago.completado,
      fechaPago: DateTime.now().toUtc(),
    );
    _pagosPorSolicitud[solicitudId] = nuevo;
    _finalizarSolicitudTrasPagoOk(solicitudId);
    notifyListeners();
    return nuevo;
  }

  /// Demo: pago completado → solicitud **FINALIZADO** (como confirmaría el backend tras cobro).
  void _finalizarSolicitudTrasPagoOk(int solicitudId) {
    final i = _solicitudes.indexWhere((s) => s.id == solicitudId);
    if (i < 0) return;
    final s = _solicitudes[i];
    if (s.estado == EstadoSolicitud.cancelado) return;
    if (s.estado != EstadoSolicitud.finalizado) {
      _solicitudes[i] = s.copyWith(estado: EstadoSolicitud.finalizado);
    }
  }

  /// Demo GPS: distancia al incidente ≤ [maxKm] y estado **EN_CAMINO** → **EN_SITIO**.
  bool marcarEnSitioSiProximo(int solicitudId, double distanciaKm, {double maxKm = 0.12}) {
    if (distanciaKm > maxKm) return false;
    _seed();
    final i = _solicitudes.indexWhere((s) => s.id == solicitudId);
    if (i < 0) return false;
    final s = _solicitudes[i];
    if (s.estado != EstadoSolicitud.enCamino) return false;
    _solicitudes[i] = s.copyWith(estado: EstadoSolicitud.enSitio);
    notifyListeners();
    return true;
  }

  /// Demo sin GPS (web / emulador): “ya llegué al lugar” solo desde **EN_CAMINO**.
  bool marcarEnSitioDemo(int solicitudId) {
    return marcarEnSitioSiProximo(solicitudId, 0);
  }
}
