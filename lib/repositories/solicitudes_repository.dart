import 'dart:convert';

import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calificacion_servicio.dart';
import '../models/cobro_extra_linea.dart';
import '../models/pago.dart';
import '../models/solicitud_auxilio.dart';
import '../mock/mock_data_store.dart';
import '../services/api_service.dart';

abstract class SolicitudesRepository {
  Future<List<SolicitudAuxilioVm>> listarPorCliente(int clienteId);
  Future<SolicitudAuxilioVm?> obtener(int id, int clienteId);
  Future<SolicitudAuxilioVm> crear({
    required int clienteId,
    required int vehiculoId,
    String? descripcion,
    required double latitud,
    required double longitud,
    String? urlImg,
    String? urlAudio,
    List<int>? fotoBytes,
    String? fotoFilename,
  });
  void demoAvanzarEstado(int solicitudId);
  Future<Pago?> pagoDeSolicitud(int solicitudId);
  Future<Pago> registrarPago({
    required int solicitudId,
    required double monto,
    required MetodoPago metodo,
  });
  Future<Pago?> completarPago(int solicitudId);

  List<CobroExtraLinea> lineasExtraCobro(int solicitudId);
  Future<void> agregarLineaExtraCobro({
    required int solicitudId,
    required String concepto,
    required double monto,
  });
  Future<bool> eliminarLineaExtraCobro({required int solicitudId, required int lineaId});
  double montoTotalSugeridoCobro(SolicitudAuxilio solicitud);

  CalificacionServicio? calificacionDeSolicitud(int solicitudId);
  Future<void> registrarCalificacion({
    required int solicitudId,
    required int clienteId,
    required int estrellas,
    String? comentario,
  });
}

class _SolicitudesRepositoryMock implements SolicitudesRepository {
  final _store = MockDataStore.instance;

  @override
  Future<List<SolicitudAuxilioVm>> listarPorCliente(int clienteId) async {
    return _store.solicitudesDeCliente(clienteId);
  }

  @override
  Future<SolicitudAuxilioVm?> obtener(int id, int clienteId) async {
    return _store.solicitudVm(id, clienteId);
  }

  @override
  Future<SolicitudAuxilioVm> crear({
    required int clienteId,
    required int vehiculoId,
    String? descripcion,
    required double latitud,
    required double longitud,
    String? urlImg,
    String? urlAudio,
    List<int>? fotoBytes,
    String? fotoFilename,
  }) {
    return _store.crearSolicitud(
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      descripcion: descripcion,
      latitud: latitud,
      longitud: longitud,
      urlImg: urlImg,
      urlAudio: urlAudio,
    );
  }

  @override
  void demoAvanzarEstado(int solicitudId) => _store.demoAvanzarEstado(solicitudId);

  @override
  Future<Pago?> pagoDeSolicitud(int solicitudId) async =>
      _store.pagoDeSolicitud(solicitudId);

  @override
  Future<Pago> registrarPago({
    required int solicitudId,
    required double monto,
    required MetodoPago metodo,
  }) {
    return _store.crearOActualizarPago(
      solicitudId: solicitudId,
      monto: monto,
      metodo: metodo,
    );
  }

  @override
  Future<Pago?> completarPago(int solicitudId) =>
      _store.marcarPagoCompletado(solicitudId);

  @override
  List<CobroExtraLinea> lineasExtraCobro(int solicitudId) =>
      _store.lineasExtraCobro(solicitudId);

  @override
  Future<void> agregarLineaExtraCobro({
    required int solicitudId,
    required String concepto,
    required double monto,
  }) async {
    _store.agregarLineaExtraCobro(solicitudId, concepto: concepto, monto: monto);
  }

  @override
  Future<bool> eliminarLineaExtraCobro({required int solicitudId, required int lineaId}) async =>
      _store.eliminarLineaExtraCobro(solicitudId, lineaId);

  @override
  double montoTotalSugeridoCobro(SolicitudAuxilio solicitud) =>
      _store.montoTotalSugeridoCobro(solicitud);

  @override
  CalificacionServicio? calificacionDeSolicitud(int solicitudId) =>
      _store.calificacionDeSolicitud(solicitudId);

  @override
  Future<void> registrarCalificacion({
    required int solicitudId,
    required int clienteId,
    required int estrellas,
    String? comentario,
  }) async {
    _store.registrarCalificacion(
      solicitudId: solicitudId,
      clienteId: clienteId,
      estrellas: estrellas,
      comentario: comentario,
    );
  }
}

class _SolicitudesRepositoryApi implements SolicitudesRepository {
  // Cache local para mostrar alta inmediata aun si la sincronización remota falla.
  static final List<SolicitudAuxilioVm> _creadasEnSesion = <SolicitudAuxilioVm>[];
  static const String _kSolicitudesCache = 'solicitudes_cache_v1';

  Future<void> _cargarCacheLocal() async {
    if (_creadasEnSesion.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kSolicitudesCache);
      if (raw == null || raw.trim().isEmpty) return;
      final data = raw.trim();
      final decoded = data.startsWith('[') ? data : '[]';
      final list = (jsonDecode(decoded) as List<dynamic>)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(
            (m) => SolicitudAuxilioVm(
              solicitud: SolicitudAuxilio.fromJson(m),
              mecanicoId: m['mecanico_id'] as int?,
              tallerNombreAsignado: m['taller_nombre_asignado'] as String?,
              mecanicoNombre: m['mecanico_nombre'] as String?,
              mecanicoTelefono: m['mecanico_telefono'] as String?,
              clienteNombre: m['cliente_nombre'] as String?,
              clienteTelefono: m['cliente_telefono'] as String?,
            ),
          )
          .toList();
      _creadasEnSesion
        ..clear()
        ..addAll(list);
    } catch (_) {}
  }

  Future<void> _guardarCacheLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      final payload = _creadasEnSesion
          .map((vm) => <String, dynamic>{
                ...vm.solicitud.toJson(),
                'mecanico_id': vm.mecanicoId,
                'taller_nombre_asignado': vm.tallerNombreAsignado,
                'mecanico_nombre': vm.mecanicoNombre,
                'mecanico_telefono': vm.mecanicoTelefono,
                'cliente_nombre': vm.clienteNombre,
                'cliente_telefono': vm.clienteTelefono,
              })
          .toList();
      await p.setString(_kSolicitudesCache, jsonEncode(payload));
    } catch (_) {}
  }

  void _upsertLocal(SolicitudAuxilioVm vm) {
    _creadasEnSesion.removeWhere((x) => x.solicitud.id == vm.solicitud.id);
    _creadasEnSesion.insert(0, vm);
    _guardarCacheLocal();
  }

  @override
  Future<List<SolicitudAuxilioVm>> listarPorCliente(int clienteId) async {
    await _cargarCacheLocal();
    try {
      final remotas = await ApiService.instance.fetchMisSolicitudesCliente();
      _creadasEnSesion.removeWhere((vm) => vm.solicitud.clienteId == clienteId);
      _creadasEnSesion.addAll(remotas);
    } catch (_) {
      // Si falla la red/backend, cae al cache local de sesión.
    }
    final list = _creadasEnSesion
        .where((vm) => vm.solicitud.clienteId == clienteId)
        .toList()
      ..sort((a, b) => b.solicitud.fechaCreacion.compareTo(a.solicitud.fechaCreacion));
    await _guardarCacheLocal();
    return list;
  }

  @override
  Future<SolicitudAuxilioVm?> obtener(int id, int clienteId) async {
    await listarPorCliente(clienteId);
    try {
      return _creadasEnSesion.firstWhere(
        (vm) => vm.solicitud.id == id && vm.solicitud.clienteId == clienteId,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SolicitudAuxilioVm> crear({
    required int clienteId,
    required int vehiculoId,
    String? descripcion,
    required double latitud,
    required double longitud,
    String? urlImg,
    String? urlAudio,
    List<int>? fotoBytes,
    String? fotoFilename,
  }) async {
    if (fotoBytes == null || fotoBytes.isEmpty) {
      throw ApiException('El backend actual requiere al menos una foto para crear solicitud.');
    }
    final desc = (descripcion ?? '').trim();
    if (desc.isEmpty) {
      throw ApiException('La descripción es obligatoria para crear la solicitud.');
    }
    final vm = await ApiService.instance.crearSolicitudApi(
      vehiculoId: vehiculoId,
      descripcion: desc,
      latitud: latitud,
      longitud: longitud,
      fotoBytes: fotoBytes,
      fotoFilename: fotoFilename ?? 'foto.jpg',
    );
    _upsertLocal(vm);
    return vm;
  }

  @override
  void demoAvanzarEstado(int solicitudId) {}

  @override
  Future<Pago?> pagoDeSolicitud(int solicitudId) async => null;

  final Map<int, List<CobroExtraLinea>> _cobrosExtra = {};

  @override
  Future<Pago> registrarPago({
    required int solicitudId,
    required double monto,
    required MetodoPago metodo,
  }) async {
    final extras = _cobrosExtra[solicitudId] ?? [];
    
    final payload = {
      "cobros_extra": extras.map((e) => {"concepto": e.concepto, "monto": e.monto}).toList(),
      "metodo_pago": metodo.name.toUpperCase(),
    };
    
    await ApiService.instance.post(
      '/solicitudes/$solicitudId/finalizar-servicio',
      payload,
    );
    
    return Pago(
      id: DateTime.now().millisecondsSinceEpoch,
      solicitudId: solicitudId,
      monto: monto,
      metodoPago: metodo,
      estadoPago: metodo == MetodoPago.efectivo ? EstadoPago.completado : EstadoPago.pendiente,
      fechaPago: DateTime.now(),
    );
  }

  @override
  Future<Pago?> completarPago(int solicitudId) async => null;

  @override
  List<CobroExtraLinea> lineasExtraCobro(int solicitudId) => _cobrosExtra[solicitudId] ?? [];

  @override
  Future<void> agregarLineaExtraCobro({
    required int solicitudId,
    required String concepto,
    required double monto,
  }) async {
    final linea = CobroExtraLinea(id: DateTime.now().millisecondsSinceEpoch, solicitudId: solicitudId, concepto: concepto, monto: monto);
    _cobrosExtra.putIfAbsent(solicitudId, () => []).add(linea);
  }

  @override
  Future<bool> eliminarLineaExtraCobro({
    required int solicitudId,
    required int lineaId,
  }) async {
    if (!_cobrosExtra.containsKey(solicitudId)) return false;
    _cobrosExtra[solicitudId]!.removeWhere((l) => l.id == lineaId);
    return true;
  }
  @override
  double montoTotalSugeridoCobro(SolicitudAuxilio solicitud) => 0;

  @override
  CalificacionServicio? calificacionDeSolicitud(int solicitudId) => null;

  @override
  Future<void> registrarCalificacion({
    required int solicitudId,
    required int clienteId,
    required int estrellas,
    String? comentario,
  }) async {
    throw UnsupportedError('Falta endpoint REST de calificaciones');
  }
}

SolicitudesRepository solicitudesRepository() {
  return ApiConfig.effectiveMockData ? _SolicitudesRepositoryMock() : _SolicitudesRepositoryApi();
}
