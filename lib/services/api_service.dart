import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/solicitud_auxilio.dart';
import '../models/taller.dart';
import '../models/vehiculo.dart';
import 'session_service.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 25);

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _jsonHeaders({bool bearer = false}) async {
    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (bearer) {
      final t = await SessionService.instance.readToken();
      if (t == null || t.isEmpty) {
        throw ApiException('No hay sesión. Iniciá sesión con un usuario cliente.');
      }
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Future<http.Response> _post(String path, {Object? body, bool bearer = false}) async {
    return _client
        .post(
          _u(path),
          headers: await _jsonHeaders(bearer: bearer),
          body: body,
        )
        .timeout(_timeout);
  }

  Future<http.Response> post(String path, Object body, {bool bearer = true}) async {
    return _client
        .post(
          _u(path),
          headers: await _jsonHeaders(bearer: bearer),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
  }

  Future<http.Response> _get(String path, {bool bearer = false}) async {
    return _client
        .get(_u(path), headers: await _jsonHeaders(bearer: bearer))
        .timeout(_timeout);
  }

  Future<http.Response> _put(String path, {Object? body}) async {
    return _client
        .put(
          _u(path),
          headers: await _jsonHeaders(bearer: true),
          body: body,
        )
        .timeout(_timeout);
  }

  Future<http.Response> _delete(String path) async {
    return _client
        .delete(_u(path), headers: await _jsonHeaders(bearer: true))
        .timeout(_timeout);
  }

  Future<String> login({required String correo, required String password}) async {
    try {
      final res = await _post(
        '/auth/login',
        body: jsonEncode({'correo': correo, 'password': password}),
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final token = map['access_token'] as String?;
        if (token != null) return token;
      }
      throw _errorFromResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Tiempo agotado al contactar ${ApiConfig.baseUrl}. '
        'En Chrome usá localhost; en emulador 10.0.2.2; verificá que el API esté en marcha.',
      );
    }
  }

  Future<void> register({
    required String nombre,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    try {
      final body = <String, dynamic>{
        'nombre': nombre,
        'correo': correo,
        'password': password,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
      };
      final res = await _post('/auth/register', body: jsonEncode(body));
      if (res.statusCode != 201) throw _errorFromResponse(res);
    } on TimeoutException {
      throw ApiException(
        'Tiempo agotado al contactar ${ApiConfig.baseUrl}. '
        'Si estás en Chrome, la URL debe ser la de tu PC (p. ej. http://localhost:8000), no 10.0.2.2.',
      );
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final token = fcmToken.trim();
    if (token.isEmpty) return;
    try {
      final res = await _put(
        '/auth/update-fcm-token',
        body: jsonEncode({'fcm_token': token}),
      );
      if (res.statusCode != 200) throw _errorFromResponse(res);
    } on TimeoutException {
      throw ApiException('Tiempo agotado al actualizar token FCM.');
    }
  }

  /// Vehículos del usuario autenticado (`GET /vehiculos/`, rol **cliente**).
  Future<List<Vehiculo>> fetchMisVehiculos() async {
    try {
      final res = await _get('/vehiculos/', bearer: true);
      if (res.statusCode != 200) throw _errorFromResponse(res);
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => Vehiculo.fromJson(e as Map<String, dynamic>)).toList();
    } on TimeoutException {
      throw ApiException('Tiempo agotado al cargar vehículos.');
    }
  }

  Future<Vehiculo> crearVehiculoApi({
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) async {
    final body = <String, dynamic>{
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'placa': placa,
      if (color != null && color.isNotEmpty) 'color': color,
    };
    final res = await _post('/vehiculos/', body: jsonEncode(body), bearer: true);
    if (res.statusCode != 201) throw _errorFromResponse(res);
    return Vehiculo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Vehiculo> actualizarVehiculoApi({
    required int id,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) async {
    final body = <String, dynamic>{
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'placa': placa,
      'color': color,
    };
    final res = await _put('/vehiculos/$id', body: jsonEncode(body));
    if (res.statusCode != 200) throw _errorFromResponse(res);
    return Vehiculo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Vehiculo> desactivarVehiculoApi(int id) async {
    final res = await _delete('/vehiculos/$id');
    if (res.statusCode != 200) throw _errorFromResponse(res);
    return Vehiculo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Vehiculo?> obtenerVehiculoApi(int id) async {
    final res = await _get('/vehiculos/$id', bearer: true);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw _errorFromResponse(res);
    return Vehiculo.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// `GET /talleres/` requiere sesión cliente/superadmin en el backend actual.
  Future<List<Taller>> fetchTalleres() async {
    try {
      final res = await _get('/talleres/', bearer: true);
      if (res.statusCode != 200) throw _errorFromResponse(res);
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => Taller.fromJson(e as Map<String, dynamic>))
          .toList();
    } on TimeoutException {
      throw ApiException(
        'Tiempo agotado al cargar talleres desde ${ApiConfig.baseUrl}.',
      );
    }
  }

  /// Crea una solicitud cliente con foto obligatoria en backend actual.
  Future<SolicitudAuxilioVm> crearSolicitudApi({
    required int vehiculoId,
    required String descripcion,
    required double latitud,
    required double longitud,
    required List<List<int>> fotosBytes,
    required List<String> fotosFilenames,
  }) async {
    final token = await SessionService.instance.readToken();
    if (token == null || token.isEmpty) {
      throw ApiException('No hay sesión. Iniciá sesión con un usuario cliente.');
    }
    final req = http.MultipartRequest('POST', _u('/solicitudes/'));
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['vehiculoId'] = '$vehiculoId';
    req.fields['descripcion'] = descripcion;
    req.fields['latitud'] = '$latitud';
    req.fields['longitud'] = '$longitud';
    for (int i = 0; i < fotosBytes.length; i++) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'fotos',
          fotosBytes[i],
          filename: fotosFilenames[i],
        ),
      );
    }

    http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(_timeout);
    } on TimeoutException {
      throw ApiException('Tiempo agotado al crear la solicitud.');
    }
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 201) throw _errorFromResponse(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final solicitud = SolicitudAuxilio.fromJson(map);
    return SolicitudAuxilioVm(
      solicitud: solicitud,
      mecanicoId: map['mecanico_id'] as int?,
      tallerNombreAsignado: (map['taller_nombre_asignado'] ?? map['taller_nombre']) as String?,
      mecanicoNombre: (map['mecanico_nombre'] ?? map['nombre_mecanico']) as String?,
      mecanicoTelefono: (map['mecanico_telefono'] ?? map['telefono_mecanico']) as String?,
      clienteNombre: (map['cliente_nombre'] ?? map['nombre_cliente']) as String?,
      clienteTelefono: map['cliente_telefono'] as String?,
    );
  }

  /// Solicitudes del cliente autenticado (`GET /solicitudes/cliente`).
  Future<List<SolicitudAuxilioVm>> fetchMisSolicitudesCliente() async {
    try {
      // Backend actual: /solicitudes/cliente.
      // Mantiene compatibilidad con despliegues viejos que usaban /mis-solicitudes.
      var res = await _get('/solicitudes/cliente', bearer: true);
      if (res.statusCode == 404) {
        res = await _get('/solicitudes/mis-solicitudes', bearer: true);
      }
      if (res.statusCode != 200) throw _errorFromResponse(res);
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => e as Map<String, dynamic>)
          .map(
            (map) => SolicitudAuxilioVm(
              solicitud: SolicitudAuxilio.fromJson(map),
              mecanicoId: map['mecanico_id'] as int?,
              tallerNombreAsignado: (map['taller_nombre_asignado'] ?? map['taller_nombre']) as String?,
              mecanicoNombre: (map['mecanico_nombre'] ?? map['nombre_mecanico']) as String?,
              mecanicoTelefono: (map['mecanico_telefono'] ?? map['telefono_mecanico']) as String?,
              clienteNombre: (map['cliente_nombre'] ?? map['nombre_cliente']) as String?,
              clienteTelefono: map['cliente_telefono'] as String?,
            ),
          )
          .toList();
    } on TimeoutException {
      throw ApiException('Tiempo agotado al consultar tus solicitudes.');
    }
  }

  /// Solicitud activa del mecánico autenticado.
  /// Backends recientes exponen `GET /solicitudes/mecanico` (lista),
  /// y despliegues anteriores usaban `GET /solicitudes/mi-servicio`.
  Future<SolicitudAuxilioVm?> fetchMiServicioMecanico() async {
    try {
      var res = await _get('/solicitudes/mecanico', bearer: true);
      if (res.statusCode == 404) {
        res = await _get('/solicitudes/mi-servicio', bearer: true);
      }
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw _errorFromResponse(res);

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is List) {
        if (decoded.isEmpty) return null;
        final maps = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        DateTime extraerFecha(Map<String, dynamic> m) {
          final raw = m['fecha_creacion'] as String?;
          return DateTime.tryParse(raw ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        }
        maps.sort((a, b) => extraerFecha(b).compareTo(extraerFecha(a)));
        for (final map in maps) {
          final s = SolicitudAuxilio.fromJson(map);
          if (s.estado == EstadoSolicitud.asignado ||
              s.estado == EstadoSolicitud.enCamino ||
              s.estado == EstadoSolicitud.enSitio) {
            return SolicitudAuxilioVm(
              solicitud: s,
              tallerId: map['taller_id'] as int?,
              mecanicoId: map['mecanico_id'] as int?,
              tallerNombreAsignado: (map['taller_nombre_asignado'] ?? map['taller_nombre']) as String?,
              mecanicoNombre: (map['mecanico_nombre'] ?? map['nombre_mecanico']) as String?,
              mecanicoTelefono: (map['mecanico_telefono'] ?? map['telefono_mecanico']) as String?,
              clienteNombre: (map['cliente_nombre'] ?? map['nombre_cliente']) as String?,
              clienteTelefono: map['cliente_telefono'] as String?,
            );
          }
        }
        // Si no encontró ninguno activo en la lista, retorna null
        return null;
      }

      final map = Map<String, dynamic>.from(decoded as Map);
      final solSingle = SolicitudAuxilio.fromJson(map);
      if (solSingle.estado == EstadoSolicitud.asignado ||
          solSingle.estado == EstadoSolicitud.enCamino ||
          solSingle.estado == EstadoSolicitud.enSitio) {
        return SolicitudAuxilioVm(
          solicitud: solSingle,
          tallerId: map['taller_id'] as int?,
          mecanicoId: map['mecanico_id'] as int?,
          tallerNombreAsignado: (map['taller_nombre_asignado'] ?? map['taller_nombre']) as String?,
          mecanicoNombre: (map['mecanico_nombre'] ?? map['nombre_mecanico']) as String?,
          mecanicoTelefono: (map['mecanico_telefono'] ?? map['telefono_mecanico']) as String?,
          clienteNombre: (map['cliente_nombre'] ?? map['nombre_cliente']) as String?,
          clienteTelefono: map['cliente_telefono'] as String?,
        );
      }
      return null;

    } on TimeoutException {
      throw ApiException('Tiempo agotado al consultar el servicio asignado.');
    }
  }

  /// Listar todos los servicios asignados al mecánico (historial completo).
  Future<List<SolicitudAuxilioVm>> fetchServiciosMecanico() async {
    try {
      final res = await _get('/solicitudes/mecanico', bearer: true);
      if (res.statusCode != 200) throw _errorFromResponse(res);
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => e as Map<String, dynamic>)
          .map(
            (map) => SolicitudAuxilioVm(
              solicitud: SolicitudAuxilio.fromJson(map),
              tallerId: map['taller_id'] as int?,
              mecanicoId: map['mecanico_id'] as int?,
              tallerNombreAsignado: (map['taller_nombre_asignado'] ?? map['taller_nombre']) as String?,
              mecanicoNombre: (map['mecanico_nombre'] ?? map['nombre_mecanico']) as String?,
              mecanicoTelefono: (map['mecanico_telefono'] ?? map['telefono_mecanico']) as String?,
              clienteNombre: (map['cliente_nombre'] ?? map['nombre_cliente']) as String?,
              clienteTelefono: map['cliente_telefono'] as String?,
            ),
          )
          .toList();
    } on TimeoutException {
      throw ApiException('Tiempo agotado al cargar el historial del mecánico.');
    }
  }

  /// Iniciar viaje del mecánico (cambia estado de ASIGNADO a EN_CAMINO)
  Future<void> iniciarViajeMecanico(int solicitudId) async {
    try {
      final res = await _post('/solicitudes/$solicitudId/iniciar-viaje', bearer: true);
      if (res.statusCode != 200) throw _errorFromResponse(res);
    } on TimeoutException {
      throw ApiException('Tiempo agotado al iniciar viaje.');
    }
  }

  /// Registrar llegada al sitio del mecánico (cambia estado de EN_CAMINO a EN_SITIO)
  Future<void> llegarASitioMecanico(int solicitudId) async {
    try {
      final res = await _post('/solicitudes/$solicitudId/llegar-sitio', bearer: true);
      if (res.statusCode != 200) throw _errorFromResponse(res);
    } on TimeoutException {
      throw ApiException('Tiempo agotado al registrar llegada al sitio.');
    }
  }

  /// Nombre del tipo de servicio por ID (`GET /tipos-servicio/{id}`).
  Future<String?> fetchNombreTipoServicio(int tipoServicioId) async {
    try {
      final res = await _get('/tipos-servicio/$tipoServicioId');
      if (res.statusCode == 404) return null;
      if (res.statusCode != 200) throw _errorFromResponse(res);
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final nombre = map['nombre'] as String?;
      return (nombre == null || nombre.trim().isEmpty) ? null : nombre.trim();
    } on TimeoutException {
      throw ApiException('Tiempo agotado al consultar el tipo de servicio.');
    }
  }

  ApiException _errorFromResponse(http.Response res) {
    try {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = map['detail'];
      if (detail is String) {
        return ApiException(detail, statusCode: res.statusCode);
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return ApiException('${first['msg']}', statusCode: res.statusCode);
        }
      }
    } catch (_) {}
    return ApiException(
      'Error del servidor (${res.statusCode})',
      statusCode: res.statusCode,
    );
  }
}
