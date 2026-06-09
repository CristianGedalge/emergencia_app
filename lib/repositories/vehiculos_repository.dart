import '../config/api_config.dart';
import '../models/vehiculo.dart';
import '../mock/mock_data_store.dart';
import '../services/api_service.dart';

abstract class VehiculosRepository {
  Future<List<Vehiculo>> listarPorCliente(int clienteId);
  Future<Vehiculo> crear({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  });
  Future<Vehiculo?> actualizar({
    required int id,
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  });
  Future<bool> desactivar(int id, int clienteId);
  Future<Vehiculo?> obtener(int id, int clienteId);
}

class _VehiculosRepositoryMock implements VehiculosRepository {
  final _store = MockDataStore.instance;

  @override
  Future<List<Vehiculo>> listarPorCliente(int clienteId) async {
    return _store.vehiculosActivosDeCliente(clienteId);
  }

  @override
  Future<Vehiculo> crear({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) {
    return _store.crearVehiculo(
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa,
      color: color,
    );
  }

  @override
  Future<Vehiculo?> actualizar({
    required int id,
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) {
    return _store.actualizarVehiculo(
      id: id,
      clienteId: clienteId,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa,
      color: color,
    );
  }

  @override
  Future<bool> desactivar(int id, int clienteId) =>
      _store.desactivarVehiculo(id, clienteId);

  @override
  Future<Vehiculo?> obtener(int id, int clienteId) async {
    return _store.vehiculoPorId(id, clienteId);
  }
}

class _VehiculosRepositoryApi implements VehiculosRepository {
  final _api = ApiService.instance;

  /// El backend filtra por JWT (`sub` = cliente); [clienteId] debe coincidir con ese usuario.
  @override
  Future<List<Vehiculo>> listarPorCliente(int clienteId) async {
    final list = await _api.fetchMisVehiculos();
    return list.where((v) => v.clienteId == clienteId && v.estado).toList();
  }

  @override
  Future<Vehiculo> crear({
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) {
    return _api.crearVehiculoApi(
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa,
      color: color,
    );
  }

  @override
  Future<Vehiculo?> actualizar({
    required int id,
    required int clienteId,
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
    String? color,
  }) {
    return _api.actualizarVehiculoApi(
      id: id,
      marca: marca,
      modelo: modelo,
      anio: anio,
      placa: placa,
      color: color,
    );
  }

  @override
  Future<bool> desactivar(int id, int clienteId) async {
    await _api.desactivarVehiculoApi(id);
    return true;
  }

  @override
  Future<Vehiculo?> obtener(int id, int clienteId) => _api.obtenerVehiculoApi(id);
}

VehiculosRepository vehiculosRepository() {
  return ApiConfig.effectiveMockData ? _VehiculosRepositoryMock() : _VehiculosRepositoryApi();
}
