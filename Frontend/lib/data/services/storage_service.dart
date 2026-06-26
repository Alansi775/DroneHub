import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/user_model.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveToken(String token) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.tokenKey);
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final prefs = await _instance;
    final json = prefs.getString(AppConstants.userKey);
    if (json == null) return null;
    return UserModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> clearUser() async {
    final prefs = await _instance;
    await prefs.remove(AppConstants.userKey);
  }

  Future<void> saveTheme(String theme) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.themeKey, theme);
  }

  Future<String?> getTheme() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.themeKey);
  }

  Future<void> clearAll() async {
    final prefs = await _instance;
    await prefs.clear();
  }
}
