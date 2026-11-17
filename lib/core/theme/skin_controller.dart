import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_skin.dart';

class SkinController extends ChangeNotifier {
  static final SkinController instance = SkinController._internal();

  SkinController._internal();

  static const String _storageKey = 'selected_app_skin_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AppSkin _currentSkin = AppSkin.midnight;

  AppSkin get currentSkin => _currentSkin;
  ThemeData get themeData => _currentSkin.toThemeData();

  Future<void> initialize() async {
    try {
      final savedId = await _storage.read(key: _storageKey);
      if (savedId != null) {
        _currentSkin = AppSkin.fromId(savedId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Erro ao carregar skin salva: $e');
    }
  }

  Future<void> setSkin(AppSkin skin) async {
    if (_currentSkin.id == skin.id) return;
    _currentSkin = skin;
    notifyListeners();

    try {
      await _storage.write(key: _storageKey, value: skin.id.name);
    } catch (e) {
      debugPrint('Erro ao persistir skin selecionada: $e');
    }
  }
}

