import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiServiceProvider),
    ref.watch(storageServiceProvider),
  );
});

class AuthRepository {
  final ApiService _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<UserModel> login(String email, String password) async {
    final res = await _api.post('/auth/login', data: {'email': email, 'password': password});
    final data = res.data as Map<String, dynamic>;
    await _storage.saveToken(data['token'] as String);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user);
    return user;
  }

  Future<UserModel?> register(String name, String email, String password) async {
    final res = await _api.post('/auth/register', data: {'name': name, 'email': email, 'password': password});
    final data = res.data as Map<String, dynamic>;
    if (data['token'] == null) return null; // email verification required
    await _storage.saveToken(data['token'] as String);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user);
    return user;
  }

  Future<UserModel> googleLogin({String? idToken, String? accessToken}) async {
    final res = await _api.post('/auth/google', data: {
      if (idToken != null) 'idToken': idToken,
      if (accessToken != null) 'accessToken': accessToken,
    });
    final data = res.data as Map<String, dynamic>;
    await _storage.saveToken(data['token'] as String);
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.saveUser(user);
    return user;
  }

  Future<UserModel?> getStoredUser() => _storage.getUser();

  Future<void> logout() async {
    await _storage.clearToken();
    await _storage.clearUser();
  }
}
