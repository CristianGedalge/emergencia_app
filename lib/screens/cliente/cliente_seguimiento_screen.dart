import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'dart:io' as io;

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/solicitud_auxilio.dart';
import '../../repositories/solicitudes_repository.dart';
import '../../utils/geo.dart';
import '../../utils/google_maps_links.dart';
import '../../utils/telefono_launch.dart';
import '../../utils/marker_utils.dart';
import '../../services/stripe_service.dart';
import '../../services/directions_service.dart';
import 'cliente_estilos_solicitud.dart';

/// Mapa cliente ↔ mecánico en marcha (MOCK: posición del mecánico simulada; producción: GPS + canal en tiempo real).
class ClienteSeguimientoScreen extends StatefulWidget {
  const ClienteSeguimientoScreen({super.key, required this.clienteId});

  final int clienteId;

  @override
  State<ClienteSeguimientoScreen> createState() => _ClienteSeguimientoScreenState();
}

class _ClienteSeguimientoScreenState extends State<ClienteSeguimientoScreen> {
  LatLng? _miPosicion;
  Timer? _tick;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final _solicitudesRepo = solicitudesRepository();
  SolicitudAuxilioVm? _apiVm;
  bool _apiLoading = false;
  String? _apiError;
  LatLng? _mecanicoPos;
  String? _etaDistancia;
  String? _etaTiempo;
  List<LatLng> _routePoints = [];
  BitmapDescriptor _mecanicoIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _cargarIconoMecanico();
    if (ApiConfig.effectiveMockData) {
      final vm = MockDataStore.instance.solicitudSeguimientoPrioritariaCliente(widget.clienteId);
      if (vm != null) {
        final mecanico = MockDataStore.instance.posicionMecanicoSimulada(vm.solicitud);
        final incidente = LatLng(vm.solicitud.latitud, vm.solicitud.longitud);
        _cargarRutaGoogle(mecanico, incidente);
      }
      _tick = Timer.periodic(const Duration(milliseconds: 900), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _refrescarSeguimientoApi();
      _connectWs();
      _tick = Timer.periodic(const Duration(seconds: 12), (_) {
        _refrescarSeguimientoApi(silent: true);
      });
    }
    _cargarGps();
  }

  void _ajustarCamara() {
    if (_mapController == null) return;
    
    final p1 = _mecanicoPos;
    final p2 = _apiVm != null ? LatLng(_apiVm!.solicitud.latitud, _apiVm!.solicitud.longitud) : null;
    
    if (p1 != null && p2 != null) {
      final minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
      final maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
      final minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
      final maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;
      
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          50.0, // padding
        ),
      );
    } else if (p2 != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(p2, 15));
    }
  }

  Future<void> _cargarIconoMecanico() async {
    try {
      final icon = await getBytesFromIcon(Icons.directions_car, Colors.green, 60);
      if (mounted) {
        setState(() {
          _mecanicoIcon = icon;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarGps() async {
    try {
      final permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() => _miPosicion = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Uri _wsUriCliente() {
    final base = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${base.path}/ws/${widget.clienteId}',
    );
  }

  void _connectWs() {
    try {
      final uriStr = _wsUriCliente().toString();
      debugPrint("WS Cliente conectando a $uriStr");
      
      // Intentamos usar dart:io directamente para atrapar errores HTTP de WebSocket
      io.WebSocket.connect(uriStr).then((ws) {
        _channel = IOWebSocketChannel(ws);
        _wsSub = _channel!.stream.listen(
          (msg) {
            debugPrint("WS Cliente msg: $msg");
            _onWsMessage(msg);
          },
          onError: (err) {
            debugPrint("WS Cliente stream err: $err");
            _scheduleWsReconnect();
          },
          onDone: () {
            debugPrint("WS Cliente stream done");
            _scheduleWsReconnect();
          },
        );
      }).catchError((e) {
        debugPrint("WS Cliente CONNECT ERROR: $e");
        _scheduleWsReconnect();
      });
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        try {
          _channel?.sink.add('ping');
        } catch (_) {}
      });
    } catch (_) {
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || ApiConfig.effectiveMockData) return;
      _connectWs();
    });
  }

  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;
    if (raw == 'pong') return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final evento = map['evento'] as String?;
      if (evento == 'ESTADO_ACTUALIZADO' || evento == 'NUEVA_EMERGENCIA') {
        _refrescarSeguimientoApi(silent: true);
      } else if (evento == 'UBICACION_MECANICO') {
        final lat = map['datos']?['lat'] as num?;
        final lng = map['datos']?['lng'] as num?;
        if (lat != null && lng != null) {
          final mPos = LatLng(lat.toDouble(), lng.toDouble());
          if (mounted) {
            setState(() {
              _mecanicoPos = mPos;
            });
            _ajustarCamara();
          }
          final inc = _apiVm != null ? LatLng(_apiVm!.solicitud.latitud, _apiVm!.solicitud.longitud) : null;
          debugPrint("DEBUG: _onWsMessage UBICACION_MECANICO received! inc = $inc");
          if (inc != null) {
            _cargarRutaGoogle(mPos, inc);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _cargarRutaGoogle(LatLng origen, LatLng destino) async {
    debugPrint("DEBUG: _cargarRutaGoogle origin: ${origen.latitude}, ${origen.longitude} destination: ${destino.latitude}, ${destino.longitude}");
    final route = await DirectionsService.instance.getRoute(origen, destino);
    if (route != null && mounted) {
      debugPrint("DEBUG: _cargarRutaGoogle SUCCESS! Distance: ${route.distance}, Time: ${route.duration}");
      setState(() {
        _routePoints = route.polylinePoints;
        _etaDistancia = route.distance;
        _etaTiempo = route.duration;
      });
      _ajustarCamaraRuta(route.polylinePoints);
    } else {
      debugPrint("DEBUG: _cargarRutaGoogle FAILED (returned null or not mounted)");
    }
  }

  void _ajustarCamaraRuta(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60.0, // padding
      ),
    );
  }

  Future<void> _refrescarSeguimientoApi({bool silent = false}) async {
    if (_apiLoading && silent) return;
    if (!silent && mounted) {
      setState(() {
        _apiLoading = true;
        _apiError = null;
      });
    } else {
      _apiLoading = true;
    }
    try {
      final list = await _solicitudesRepo.listarPorCliente(widget.clienteId);
      SolicitudAuxilioVm? activa;
      for (final vm in list) {
        final e = vm.solicitud.estado;
        if (e == EstadoSolicitud.aceptado ||
            e == EstadoSolicitud.asignado ||
            e == EstadoSolicitud.enCamino ||
            e == EstadoSolicitud.enSitio ||
            (e == EstadoSolicitud.finalizado && solicitudSigueAbierta(vm.solicitud))) {
          activa = vm;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _apiVm = activa;
        _apiError = null;
        _apiLoading = false;
      });
      
      if (_mecanicoPos != null && activa != null) {
        final inc = LatLng(activa.solicitud.latitud, activa.solicitud.longitud);
        _cargarRutaGoogle(_mecanicoPos!, inc);
        _ajustarCamara();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiError = '$e';
        _apiLoading = false;
      });
    }
  }

  @override
  void dispose() {
    MockDataStore.instance.removeListener(_onStore);
    _tick?.cancel();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _abrirGoogleMaps(BuildContext context, Uri uri) async {
    try {
      final ok = await GoogleMapsLinks.open(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  Future<void> _llamarMecanico(BuildContext context, String telefono) async {
    try {
      final ok = await abrirLlamadaTelefono(telefono);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada.')),
        );
      }
    }
  }

  LatLng _centro(SolicitudAuxilio s, LatLng mecanico) {
    final incidente = LatLng(s.latitud, s.longitud);
    if (_miPosicion != null) {
      return LatLng(
        (_miPosicion!.latitude + mecanico.latitude + incidente.latitude) / 3,
        (_miPosicion!.longitude + mecanico.longitude + incidente.longitude) / 3,
      );
    }
    return LatLng(
      (mecanico.latitude + incidente.latitude) / 2,
      (mecanico.longitude + incidente.longitude) / 2,
    );
  }

  String _mensajeEstado(EstadoSolicitud estado) {
    switch (estado) {
      case EstadoSolicitud.asignado:
        return '¡Tu mecánico ya fue asignado!';
      case EstadoSolicitud.enCamino:
        return 'El mecánico va en camino hacia tu ubicación.';
      case EstadoSolicitud.enSitio:
        return 'El mecánico llegó a tu ubicación.';
      case EstadoSolicitud.finalizado:
        return 'El servicio ha finalizado. Por favor procede con el pago.';
      default:
        return 'Solicitud aceptada; esperando asignación.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ApiConfig.effectiveMockData) {
      final markers = <Marker>{};
      if (_miPosicion != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('mi_posicion'),
            position: _miPosicion!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Tu ubicación'),
          ),
        );
      }
      final incidente =
          _apiVm != null ? LatLng(_apiVm!.solicitud.latitud, _apiVm!.solicitud.longitud) : null;
      if (incidente != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('incidente'),
            position: incidente,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Tu pedido / incidente'),
          ),
        );
      }
      if (_mecanicoPos != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('mecanico'),
            position: _mecanicoPos!,
            icon: _mecanicoIcon,
            infoWindow: const InfoWindow(title: 'Ubicación del mecánico'),
          ),
        );
      }
      final center = incidente ??
          _mecanicoPos ??
          _miPosicion ??
          const LatLng(-17.783327, -63.182140); // Santa Cruz fallback

      return Scaffold(
        appBar: AppBar(
          title: const Text('Seguimiento'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reconectar rastreo',
              onPressed: () {
                debugPrint("Forzando reconexión WS manualmente...");
                _connectWs();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reconectando GPS del mecánico...')),
                );
              },
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_apiLoading) const LinearProgressIndicator(),
                  if (_apiError != null) ...[
                    Text(
                      'No se pudo actualizar seguimiento: $_apiError',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (_apiVm == null)
                    Text(
                      'Tu solicitud está en espera. Cuando el taller asigne un mecánico, aquí verás el seguimiento en el mapa.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else ...[
                    Text(
                      'Solicitud #${_apiVm!.solicitud.id} · ${_apiVm!.solicitud.estado.valorApi}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _mensajeEstado(_apiVm!.solicitud.estado),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_apiVm!.mecanicoNombre != null && _apiVm!.mecanicoNombre!.trim().isNotEmpty)
                      Text('Mecánico: ${_apiVm!.mecanicoNombre}'),
                    if (_apiVm!.mecanicoTelefono != null &&
                        _apiVm!.mecanicoTelefono!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _llamarMecanico(context, _apiVm!.mecanicoTelefono!),
                        icon: const Icon(Icons.call),
                        label: const Text('Llamar'),
                      ),
                    ],
                    if (_apiVm!.solicitud.precioEstimado != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Precio Estimado: ${_apiVm!.solicitud.precioEstimado!.toStringAsFixed(2)} Bs',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                    if (_apiVm!.solicitud.estado == EstadoSolicitud.finalizado) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final exito = await StripeService.instance.procesarPago(
                            solicitudId: _apiVm!.solicitud.id,
                            cobrosExtra: [], // En una versión completa, leeríamos esto del backend
                          );
                          if (exito && context.mounted) {
                            pagosLocalesCompletados.add(_apiVm!.solicitud.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('¡Pago exitoso y servicio finalizado!')),
                            );
                            Navigator.of(context).pop();
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('El pago no pudo ser completado o fue cancelado.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Pagar ahora con Tarjeta'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (ctrl) {
                      _mapController = ctrl;
                      _ajustarCamara();
                      if (_routePoints.isNotEmpty) {
                        _ajustarCamaraRuta(_routePoints);
                      }
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    initialCameraPosition: CameraPosition(
                      target: center,
                      zoom: 13,
                    ),
                    polylines: {
                      if (_routePoints.isNotEmpty)
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routePoints,
                          color: Colors.blueAccent,
                          width: 4,
                        ),
                    },
                    markers: markers,
                  ),
                  if (_etaTiempo != null && _etaDistancia != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Llegada del mecánico en $_etaTiempo',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 16),
                                  ),
                                  Text(
                                    'Distancia: $_etaDistancia',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: MockDataStore.instance,
      builder: (context, _) {
        final vm = MockDataStore.instance.solicitudSeguimientoPrioritariaCliente(widget.clienteId);
        if (vm == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Seguimiento')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No tenés un servicio con mecánico asignado en estado asignado, en camino o en sitio.\n\n'
                  'Cuando un taller acepte y asigne desde la web, acá verás el mapa en vivo (en demostración la posición del mecánico se simula).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }

        final s = vm.solicitud;
        final mecanico = MockDataStore.instance.posicionMecanicoSimulada(s);
        final incidente = LatLng(s.latitud, s.longitud);
        final kmMec = distanciaKm(mecanico, incidente);

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('incidente_mock'),
            position: incidente,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Tu pedido / incidente'),
          ),
          Marker(
            markerId: const MarkerId('mecanico_mock'),
            position: mecanico,
            icon: _mecanicoIcon,
            infoWindow: const InfoWindow(title: 'Mecánico (demo)'),
          ),
        };
        if (_miPosicion != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('mi_posicion_mock'),
              position: _miPosicion!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Tu ubicación'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Seguimiento en vivo')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitud #${s.id} · ${s.estado.valorApi}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (vm.tallerNombreAsignado != null)
                      Text(
                        'Taller: ${vm.tallerNombreAsignado}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    Text(
                      kmMec != null
                          ? 'Distancia aprox. mecánico–incidente: ${kmMec.toStringAsFixed(2)} km (demo)'
                          : 'Actualizando posición…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: (ctrl) => _mapController = ctrl,
                      initialCameraPosition: CameraPosition(
                        target: _centro(s, mecanico),
                        zoom: 13,
                      ),
                      polylines: {
                        if (_routePoints.isNotEmpty)
                          Polyline(
                            polylineId: const PolylineId('route_mock'),
                            points: _routePoints,
                            color: Colors.blueAccent,
                            width: 4,
                          ),
                      },
                      markers: markers,
                    ),
                    if (_etaTiempo != null && _etaDistancia != null)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.directions_car, color: Theme.of(context).colorScheme.onPrimaryContainer),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Llegada del mecánico en $_etaTiempo',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 16),
                                    ),
                                    Text(
                                      'Distancia: $_etaDistancia',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _abrirGoogleMaps(
                        context,
                        GoogleMapsLinks.drivingToDestination(s.latitud, s.longitud),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Ruta al auxilio (Google Maps)'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _abrirGoogleMaps(
                        context,
                        GoogleMapsLinks.searchLocation(
                          mecanico.latitude,
                          mecanico.longitude,
                        ),
                      ),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: const Text('Ubicación del mecánico (Google Maps)'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Google Maps usa tu ubicación actual como inicio en “Ruta al auxilio”. '
                      '“Ubicación del mecánico” abre el pin donde está el móvil del mecánico (en demo se simula; en producción vendría del servidor).',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Mapa integrado: OpenStreetMap. Los botones abren Google Maps en el navegador o en la app.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
