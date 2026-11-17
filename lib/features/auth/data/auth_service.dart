import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/database/local_database_helper.dart';
import '../../../core/services/biometric_service.dart';
import '../models/user_model.dart';

class AuthResult {
  final bool success;
  final String? errorMessage;
  final UserModel? user;
  final OrganizationModel? organization;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.organization,
  });
}

class AuthService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;
  final BiometricService _biometricService = BiometricService();

  /// Cadastro / Criação de novo Workspace e Usuário Local
  Future<AuthResult> register({
    required String name,
    required String email,
    required String workspaceName,
    required String password,
  }) async {
    try {
      final db = await _dbHelper.database;
      final cleanEmail = email.trim().toLowerCase();
      final cleanName = name.trim().isEmpty ? 'Usuário' : name.trim();
      final cleanWorkspace = workspaceName.trim().isEmpty
          ? 'Finanças Pessoais'
          : workspaceName.trim();

      final nowIso = DateTime.now().toIso8601String();

      // Verifica se já existe algum usuário no SQLite
      final existingUsers = await db.query('users', limit: 1);

      String userId;
      if (existingUsers.isNotEmpty) {
        userId = existingUsers.first['id'] as String;
        await db.update(
          'users',
          {
            'name': cleanName,
            'email': cleanEmail.isNotEmpty ? cleanEmail : 'usuario@financas.local',
            'workspace_name': cleanWorkspace,
            'password_hash': password.isNotEmpty ? password : null,
            'biometrics_enabled': 0,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
      } else {
        userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
        await db.insert('users', {
          'id': userId,
          'name': cleanName,
          'email': cleanEmail.isNotEmpty ? cleanEmail : 'usuario@financas.local',
          'workspace_name': cleanWorkspace,
          'password_hash': password.isNotEmpty ? password : null,
          'biometrics_enabled': 0,
          'created_at': nowIso,
        });
      }

      final user = UserModel(
        id: userId,
        email: cleanEmail.isNotEmpty ? cleanEmail : 'usuario@financas.local',
        fullName: cleanName,
      );

      final org = OrganizationModel(
        organizationId: 'workspace_$userId',
        name: cleanWorkspace,
      );

      // Salva sessão segura local de forma ultra-resiliente
      await _biometricService.saveSession(
        token: 'local_offline_token',
        organizationId: org.organizationId,
        userJson: jsonEncode(user.toJson()),
      );
      await _biometricService.saveWorkspaceName(cleanWorkspace);
      // Biometria desligada por padrão até o usuário ativar intencionalmente
      await _biometricService.setBiometricsEnabled(false);

      return AuthResult(
        success: true,
        user: user,
        organization: org,
      );
    } catch (e) {
      debugPrint('Erro em AuthService.register: $e');
      return AuthResult(
        success: false,
        errorMessage: 'Erro ao criar conta ou workspace: $e',
      );
    }
  }

  /// Login do usuário no banco SQLite local (100% tolerante e funcional)
  Future<AuthResult> login(String email, String password) async {
    try {
      final db = await _dbHelper.database;
      final cleanEmail = email.trim();

      // 1. Busca qualquer usuário cadastrado no SQLite
      List<Map<String, dynamic>> allUsers = await db.query('users', orderBy: 'created_at ASC');

      // Se o banco não tiver usuário nenhum (ex: primeira instalação), cria um automaticamente!
      if (allUsers.isEmpty) {
        final userId = 'local_user_default';
        final nowIso = DateTime.now().toIso8601String();
        await db.insert('users', {
          'id': userId,
          'name': 'Usuário Principal',
          'email': cleanEmail.isNotEmpty ? cleanEmail : 'usuario@financas.local',
          'workspace_name': 'Finanças Pessoais',
          'password_hash': password.isNotEmpty ? password : null,
          'biometrics_enabled': 0,
          'created_at': nowIso,
        });
        allUsers = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      }

      // Procura primeiro pelo e-mail fornecido, senão usa o usuário existente
      Map<String, dynamic> userData = allUsers.first;
      if (cleanEmail.isNotEmpty) {
        final matching = allUsers.where(
          (u) => (u['email'] as String?)?.toLowerCase() == cleanEmail.toLowerCase(),
        );
        if (matching.isNotEmpty) {
          userData = matching.first;
        } else {
          // Atualiza o e-mail do usuário padrão para o que o usuário acabou de digitar
          await db.update(
            'users',
            {'email': cleanEmail},
            where: 'id = ?',
            whereArgs: [userData['id']],
          );
          userData = Map<String, dynamic>.from(userData)..['email'] = cleanEmail;
        }
      }

      final savedPass = userData['password_hash'] as String?;

      // Se houver uma senha salva e o usuário digitou uma senha diferente, avisa
      if (savedPass != null && savedPass.isNotEmpty && password.isNotEmpty && savedPass != password) {
        return AuthResult(
          success: false,
          errorMessage: 'Senha incorreta para este usuário local.',
        );
      }

      // Se não havia senha e o usuário digitou uma senha, salva como a nova senha
      if ((savedPass == null || savedPass.isEmpty) && password.isNotEmpty) {
        await db.update(
          'users',
          {'password_hash': password},
          where: 'id = ?',
          whereArgs: [userData['id']],
        );
      }

      final workspaceName = (userData['workspace_name'] as String?)?.isNotEmpty == true
          ? userData['workspace_name'] as String
          : 'Finanças Pessoais';

      final user = UserModel(
        id: userData['id'] as String,
        email: userData['email'] as String? ?? 'usuario@financas.local',
        fullName: userData['name'] as String? ?? 'Usuário Principal',
      );

      final org = OrganizationModel(
        organizationId: 'workspace_${user.id}',
        name: workspaceName,
      );

      // Salva sessão segura
      await _biometricService.saveSession(
        token: 'local_offline_token',
        organizationId: org.organizationId,
        userJson: jsonEncode(user.toJson()),
      );
      await _biometricService.saveWorkspaceName(workspaceName);

      return AuthResult(
        success: true,
        user: user,
        organization: org,
      );
    } catch (e) {
      debugPrint('Erro no login offline: $e');
      return AuthResult(
        success: false,
        errorMessage: 'Erro ao autenticar: $e',
      );
    }
  }

  /// Recupera o nome do workspace ativo
  Future<String> getCurrentWorkspaceName() async {
    final saved = await _biometricService.getSavedWorkspaceName();
    if (saved != null && saved.isNotEmpty) return saved;

    try {
      final db = await _dbHelper.database;
      final rows = await db.query('users', limit: 1);
      if (rows.isNotEmpty) {
        final ws = rows.first['workspace_name'] as String?;
        if (ws != null && ws.isNotEmpty) return ws;
      }
    } catch (_) {}
    return 'Finanças Pessoais';
  }

  Future<void> logout() async {
    await _biometricService.clearSession();
  }
}
