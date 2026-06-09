import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../models/taller.dart';
import '../../repositories/talleres_repository.dart';
import '../../utils/geo.dart';

/// Mapa de talleres (API o datos mock según [ApiConfig.effectiveMockData]).
class ClienteMapaScreen extends StatefulWidget {
  const ClienteMapaScreen({super.key, required this.clienteId});

  final int clienteId;

  @override
  State<ClienteMapaScreen> createState() => _ClienteMapaScreenState();
}

class _ClienteMapaScreenState extends State<ClienteMapaScreen> {
  final _repo = talleresRepository();
  bool _loading = true;
  String? _error;
  List<Taller> _talleres = [];
  LatLng? _miPosicion;

  static final _fallbackCentro = LatLng(-17.783327, -63.182140);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final permiso = await Geolocator.requestPermission();
      if (permiso != LocationPermission.denied &&
          permiso != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition();
        _miPosicion = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}

    try {
      // List.from: el mock devuelve lista no modificable; .sort() in-place fallaría en web/móvil.
      final list = List<Taller>.from(await _repo.listar())
        ..sort((a, b) {
          final da = _km(a);
          final db = _km(b);
          if (da == null && db == null) return a.nombre.compareTo(b.nombre);
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
      if (mounted) {
        setState(() {
          _talleres = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  double? _km(Taller t) {
    if (!_ubicacionValida(t)) return null;
    return distanciaKm(
      _miPosicion,
      LatLng(t.latitud!, t.longitud!),
    );
  }

  bool _ubicacionValida(Taller t) =>
      t.latitud != null && t.longitud != null && t.latitud!.abs() > 1e-6 && t.longitud!.abs() > 1e-6;

  LatLng _centroMapa() {
    if (_miPosicion != null) return _miPosicion!;
    for (final t in _talleres) {
      if (_ubicacionValida(t)) {
        return LatLng(t.latitud!, t.longitud!);
      }
    }
    return _fallbackCentro;
  }

  Set<Marker> _marcadores() {
    final markers = <Marker>{};
    if (_miPosicion != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mi_posicion'),
          position: _miPosicion!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
        ),
      );
    }
    for (final t in _talleres) {
      if (!_ubicacionValida(t)) continue;
      markers.add(
        Marker(
          markerId: MarkerId('taller_${t.id}'),
          position: LatLng(t.latitud!, t.longitud!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: t.nombre, snippet: t.direccion),
        ),
      );
    }
    return markers;
  }

  Future<void> _llamar(String telefono) async {
    final uri = Uri(scheme: 'tel', path: telefono.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _abrirMapsExterno(Taller t) async {
    if (!_ubicacionValida(t)) return;
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${t.latitud}&mlon=${t.longitud}&zoom=16',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapa = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Text(
                        'Servidor: ${ApiConfig.baseUrl}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (_miPosicion == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const ListTile(
                          dense: true,
                          leading: Icon(Icons.info_outline),
                          title: Text(
                            'Sin ubicación GPS: el mapa se centra en Santa Cruz o en el primer taller con coordenadas.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.36,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _centroMapa(),
                        zoom: 13,
                      ),
                      markers: _marcadores(),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Lista (${_talleres.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        Text(
                          'Leyenda: vos ',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Icon(Icons.person_pin_circle, color: Colors.blue, size: 18),
                        const Text('  taller '),
                        const Icon(Icons.build_circle, color: Colors.deepOrange, size: 18),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _talleres.length,
                      itemBuilder: (context, i) {
                        final t = _talleres[i];
                        final km = _km(t);
                        final telLine = (t.telefono != null && t.telefono!.trim().isNotEmpty)
                            ? 'Tel: ${t.telefono}'
                            : 'Tel: no registrado en el sistema';
                        final extra = [
                          if (km != null) '~ ${km.toStringAsFixed(1)} km',
                          if (!_ubicacionValida(t)) 'Sin coordenadas en el mapa',
                        ].join(' · ');
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text(t.nombre),
                            subtitle: Text(
                              '${t.direccion}\n$telLine${extra.isEmpty ? '' : '\n$extra'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                if (t.telefono != null && t.telefono!.trim().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.call),
                                    tooltip: 'Llamar',
                                    onPressed: () => _llamar(t.telefono!),
                                  ),
                                if (_ubicacionValida(t))
                                  IconButton(
                                    icon: const Icon(Icons.map_outlined),
                                    tooltip: 'Abrir en mapa',
                                    onPressed: () => _abrirMapsExterno(t),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Talleres'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: mapa,
    );
  }
}
