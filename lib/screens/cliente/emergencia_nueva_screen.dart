import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../config/api_config.dart';
import '../../mock/mock_data_store.dart';
import '../../models/vehiculo.dart';
import '../../repositories/vehiculos_repository.dart';
import '../../repositories/solicitudes_repository.dart';

class EmergenciaNuevaScreen extends StatefulWidget {
  const EmergenciaNuevaScreen({super.key, required this.clienteId});

  final int clienteId;

  @override
  State<EmergenciaNuevaScreen> createState() => _EmergenciaNuevaScreenState();
}

class _EmergenciaNuevaScreenState extends State<EmergenciaNuevaScreen> {
  final _desc = TextEditingController();
  final _lat = TextEditingController(text: '-17.783327');
  final _lng = TextEditingController(text: '-63.182140');
  final _solicitudesRepo = solicitudesRepository();
  final _picker = ImagePicker();
  final _speech = SpeechToText();
  GoogleMapController? _mapController;

  int? _vehiculoId;
  List<Vehiculo> _vehiculos = [];
  final List<XFile> _fotosAdjuntas = [];
  bool _busy = false;
  bool _speechDisponible = false;
  bool _dictando = false;

  @override
  void initState() {
    super.initState();
    _cargarVehiculos();
    _actualizarUbicacion();
    _initSpeech();
  }

  @override
  void dispose() {
    _speech.stop();
    _desc.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voz: ${e.errorMsg}')),
        );
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _dictando = false);
        }
      },
    );
    if (mounted) setState(() => _speechDisponible = ok);
  }

  Future<void> _cargarVehiculos() async {
    if (ApiConfig.effectiveMockData) {
      _vehiculos = MockDataStore.instance.vehiculosActivosDeCliente(widget.clienteId);
    } else {
      _vehiculos = await vehiculosRepository().listarPorCliente(widget.clienteId);
    }
    if (_vehiculos.isNotEmpty && _vehiculoId == null) {
      _vehiculoId = _vehiculos.first.id;
    }
    if (mounted) setState(() {});
  }

  Future<void> _actualizarUbicacion() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _lat.text = '-17.783327';
        _lng.text = '-63.182140';
        setState(() {});
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _lat.text = pos.latitude.toStringAsFixed(7);
      _lng.text = pos.longitude.toStringAsFixed(7);
      try {
        _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
      } catch (_) {}
    } catch (_) {
      _lat.text = '-17.783327';
      _lng.text = '-63.182140';
    }
    if (mounted) setState(() {});
  }

  Future<void> _tomarFoto() async {
    final img = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
    if (img == null) return;
    setState(() => _fotosAdjuntas.add(img));
  }

  Future<void> _elegirGaleria() async {
    final imgs = await _picker.pickMultiImage(imageQuality: 75);
    if (imgs.isEmpty) return;
    setState(() => _fotosAdjuntas.addAll(imgs));
  }

  Future<void> _toggleDictado() async {
    if (!_speechDisponible) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconocimiento de voz no disponible. Revisá permisos de micrófono.'),
          ),
        );
      }
      return;
    }
    if (_dictando) {
      await _speech.stop();
      if (mounted) setState(() => _dictando = false);
      return;
    }
    setState(() => _dictando = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final t = result.recognizedWords;
        setState(() {
          _desc.text = t;
          _desc.selection = TextSelection.collapsed(offset: t.length);
        });
      },
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 4),
      localeId: 'es_ES',
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _enviar() async {
    if (_vehiculoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitás al menos un vehículo activo.')),
      );
      return;
    }
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitud / longitud inválidas')),
      );
      return;
    }
    if (!ApiConfig.effectiveMockData) {
      if (_desc.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En API la descripción es obligatoria (podés dictarla con el micrófono).')),
        );
        return;
      }
      if (_fotosAdjuntas.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En API necesitás adjuntar al menos una foto.')),
        );
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final urlImg = _fotosAdjuntas.isNotEmpty ? 'mock://${_fotosAdjuntas.first.path}' : null;
      final List<List<int>> bytesList = [];
      final List<String> namesList = [];
      for (final f in _fotosAdjuntas) {
        bytesList.add(await f.readAsBytes());
        namesList.add(f.name);
      }
      
      await _solicitudesRepo.crear(
        clienteId: widget.clienteId,
        vehiculoId: _vehiculoId!,
        descripcion: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        latitud: lat,
        longitud: lng,
        urlImg: urlImg,
        urlAudio: null,
        fotosBytes: bytesList.isNotEmpty ? bytesList : null,
        fotosFilenames: namesList.isNotEmpty ? namesList : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud registrada')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = !ApiConfig.effectiveMockData;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva emergencia')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu pedido se envía a los talleres por la web. Uno acepta y asigna al mecánico; '
                      'vos lo seguís en Inicio y en Seguimiento.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('1. Vehículo', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_vehiculos.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Necesitás al menos un vehículo activo.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.directions_car_outlined),
                      label: const Text('Ir a la pestaña Vehículos'),
                    ),
                  ],
                ),
              ),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '¿Con qué vehículo necesitás ayuda?',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _vehiculoId,
                  isExpanded: true,
                  hint: const Text('Elegí un vehículo'),
                  items: _vehiculos
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('${v.marca} ${v.modelo} · ${v.placa}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _vehiculoId = v),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text('2. Qué pasó', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Ej.: pinchazo en rueda delantera, no arranca… (o dictá con el botón de micrófono)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _toggleDictado,
              icon: Icon(_dictando ? Icons.stop : Icons.mic_none),
              label: Text(_dictando ? 'Detener dictado' : 'Dictar descripción'),
            ),
          ),
          const SizedBox(height: 20),
          Text('3. Ubicación', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _actualizarUbicacion,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Mi ubicación actual (GPS)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Toca en el mapa para marcar la ubicación del auxilio:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
              },
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  double.tryParse(_lat.text) ?? -17.783327,
                  double.tryParse(_lng.text) ?? -63.182140,
                ),
                zoom: 15,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (LatLng point) {
                setState(() {
                  _lat.text = point.latitude.toStringAsFixed(7);
                  _lng.text = point.longitude.toStringAsFixed(7);
                });
              },
              markers: {
                Marker(
                  markerId: const MarkerId('pos'),
                  position: LatLng(
                    double.tryParse(_lat.text) ?? -17.783327,
                    double.tryParse(_lng.text) ?? -63.182140,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Coordenadas: ${_lat.text}, ${_lng.text}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text('4. Foto de evidencia', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            api
                ? 'El servidor requiere al menos una foto (se sube al crear la solicitud). La voz solo completa el texto de la descripción; no se envía audio.'
                : 'En modo demo podés enviar sin foto; con API real hace falta al menos una imagen.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Foto cámara'),
              ),
              OutlinedButton.icon(
                onPressed: _elegirGaleria,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ],
          ),
          if (_fotosAdjuntas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Imágenes adjuntas (${_fotosAdjuntas.length}):', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final f in _fotosAdjuntas)
                    Text('• ${f.name}', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _enviar,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar solicitud de auxilio'),
          ),
        ],
      ),
    );
  }
}
