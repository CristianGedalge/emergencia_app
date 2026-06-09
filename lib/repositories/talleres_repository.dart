import '../config/api_config.dart';
import '../models/taller.dart';
import '../mock/mock_data_store.dart';
import '../services/api_service.dart';

abstract class TalleresRepository {
  Future<List<Taller>> listar();
}

class _TalleresRepositoryApi implements TalleresRepository {
  @override
  Future<List<Taller>> listar() => ApiService.instance.fetchTalleres();
}

class _TalleresRepositoryMock implements TalleresRepository {
  @override
  Future<List<Taller>> listar() async {
    MockDataStore.instance.ensureSeed();
    return MockDataStore.instance.talleres;
  }
}

TalleresRepository talleresRepository() {
  return ApiConfig.effectiveMockData ? _TalleresRepositoryMock() : _TalleresRepositoryApi();
}
