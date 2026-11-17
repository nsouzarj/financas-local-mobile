import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../database/local_database_helper.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyBiometricsEnabled = 'biometrics_enabled';
  static const String _keyJwtToken = 'jwt_token';
  static const String _keyOrgId = 'organization_id';
  static const String _keyUserJson = 'user_data';
  static const String _keyWorkspaceName = 'workspace_name';

  /// Verifica se o dispositivo possui hardware biométrico configurado e ativo
  Future<bool> canAuthenticateWithBiometrics() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Erro ao verificar suporte biométrico: $e');
      return false;
    }
  }

  /// Retorna os tipos de biometria disponíveis no celular (digital, face, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Verifica se o dispositivo possui suporte a biometria
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Verifica se há biometrias cadastradas no celular
  Future<bool> hasBiometrics() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      final canCheck = await _auth.canCheckBiometrics;
      return canCheck && available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Retorna true SOMENTE se o usuário tiver explicitamente ativado a biometria
  Future<bool> isBiometricEnabledByUser() async {
    try {
      final enabled = await _storage.read(key: _keyBiometricsEnabled);
      if (enabled != null) {
        return enabled == 'true';
      }
    } catch (e) {
      debugPrint('Aviso ao ler biometrics_enabled do storage: $e');
    }

    try {
      final db = await LocalDatabaseHelper.instance.database;
      final rows = await db.query('users', limit: 1);
      if (rows.isNotEmpty) {
        final val = rows.first['biometrics_enabled'] as int?;
        return val == 1;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> isBiometricsEnabled() => isBiometricEnabledByUser();

  /// Salva a preferência de biometria
  Future<void> setBiometricsEnabled(bool enabled) async {
    try {
      await _storage.write(
        key: _keyBiometricsEnabled,
        value: enabled ? 'true' : 'false',
      );
    } catch (e) {
      debugPrint('Aviso ao gravar biometrics_enabled no storage: $e');
    }

    try {
      final db = await LocalDatabaseHelper.instance.database;
      await db.rawUpdate(
        'UPDATE users SET biometrics_enabled = ?',
        [enabled ? 1 : 0],
      );
    } catch (e) {
      debugPrint('Aviso ao gravar biometrics_enabled no SQLite: $e');
    }
  }

  /// Aciona a janela nativa do Android/iOS para leitura da impressão digital ou FaceID
  Future<bool> authenticate({String? customMessage}) async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        debugPrint('Biometria não disponível ou sem suporte no aparelho.');
        return false;
      }

      final didAuth = await _auth.authenticate(
        localizedReason: customMessage ?? 'Toque no sensor biométrico para acessar suas finanças',
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
      return didAuth;
    } on PlatformException catch (e) {
      debugPrint('PlatformException na autenticação biométrica: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Erro inesperado na biometria: $e');
      return false;
    }
  }

  /// Cancela qualquer autenticação biométrica em andamento no Android/iOS
  Future<bool> stopAuthentication() async {
    try {
      return await _auth.stopAuthentication();
    } catch (e) {
      debugPrint('Aviso ao cancelar autenticação biométrica: $e');
      return false;
    }
  }

  /// Salva sessão segura após login
  Future<void> saveSession({
    required String token,
    required String organizationId,
    required String userJson,
  }) async {
    try {
      await _storage.write(key: _keyJwtToken, value: token);
      await _storage.write(key: _keyOrgId, value: organizationId);
      await _storage.write(key: _keyUserJson, value: userJson);
    } catch (e) {
      debugPrint('Aviso ao gravar sessão no SecureStorage: $e');
    }
  }

  /// Recupera o token JWT salvo
  Future<String?> getSavedToken() async {
    try {
      final token = await _storage.read(key: _keyJwtToken);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (e) {
      debugPrint('Aviso ao ler token do SecureStorage: $e');
    }

    try {
      final db = await LocalDatabaseHelper.instance.database;
      final users = await db.query('users', limit: 1);
      if (users.isNotEmpty) {
        return 'local_offline_token';
      }
    } catch (_) {}

    return null;
  }

  /// Recupera o ID da organização salvo
  Future<String?> getSavedOrgId() async {
    try {
      final orgId = await _storage.read(key: _keyOrgId);
      if (orgId != null && orgId.isNotEmpty) {
        return orgId;
      }
    } catch (_) {}
    return 'default_org';
  }

  /// Salva e recupera o nome do Workspace local
  Future<void> saveWorkspaceName(String name) async {
    try {
      await _storage.write(key: _keyWorkspaceName, value: name);
    } catch (_) {}
  }

  Future<String?> getSavedWorkspaceName() async {
    try {
      final ws = await _storage.read(key: _keyWorkspaceName);
      if (ws != null && ws.isNotEmpty) return ws;
    } catch (_) {}

    try {
      final db = await LocalDatabaseHelper.instance.database;
      final rows = await db.query('users', limit: 1);
      if (rows.isNotEmpty) {
        final wsDb = rows.first['workspace_name'] as String?;
        if (wsDb != null && wsDb.isNotEmpty) return wsDb;
      }
    } catch (_) {}
    return 'Finanças Pessoais';
  }

  /// Limpa todas as credenciais (Logout)
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _keyJwtToken);
      await _storage.delete(key: _keyOrgId);
      await _storage.delete(key: _keyUserJson);
      await _storage.delete(key: _keyBiometricsEnabled);
      await _storage.delete(key: _keyWorkspaceName);
    } catch (_) {}

    try {
      final db = await LocalDatabaseHelper.instance.database;
      await db.rawUpdate('UPDATE users SET biometrics_enabled = 0');
    } catch (_) {}
  }
}
