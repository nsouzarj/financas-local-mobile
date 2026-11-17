import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'local_database_helper.dart';

class BackupItem {
  final String fileName;
  final String filePath;
  final String type; // 'pre_upgrade', 'manual', 'json'
  final DateTime createdAt;
  final int sizeBytes;

  const BackupItem({
    required this.fileName,
    required this.filePath,
    required this.type,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(createdAt);
  }
}

class BackupService {
  static final BackupService instance = BackupService._internal();
  BackupService._internal();

  static const String _dbFileName = 'financas_local.db';

  /// Obtém o diretório seguro de backups
  Future<Directory> getBackupsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDocDir.path, 'financas_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// REQUISITO OBRIGATÓRIO: Cópia de segurança automática executada ANTES de qualquer migração/atualização do banco
  Future<BackupItem?> createPreUpdateBackup({int? oldVersion, int? newVersion}) async {
    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, _dbFileName));

    if (!await dbFile.exists()) {
      debugPrint('Banco de dados ainda não existe no disco, backup pré-atualização dispensado.');
      return null;
    }

    final backupDir = await getBackupsDirectory();
    final timeStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'backup_pre_upgrade_v${oldVersion ?? 0}_v${newVersion ?? 0}_$timeStr.db';
    final targetPath = p.join(backupDir.path, fileName);

    final copiedFile = await dbFile.copy(targetPath);
    final size = await copiedFile.length();

    debugPrint('🛡️ BACKUP PRÉ-ATUALIZAÇÃO CRIADO COM SUCESSO: $targetPath ($size bytes)');

    return BackupItem(
      fileName: fileName,
      filePath: targetPath,
      type: 'pre_upgrade',
      createdAt: DateTime.now(),
      sizeBytes: size,
    );
  }

  /// Cria um backup manual sob demanda do usuário
  Future<BackupItem> createManualBackup() async {
    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, _dbFileName));

    if (!await dbFile.exists()) {
      // Força inicialização do banco caso ainda não exista
      await LocalDatabaseHelper.instance.database;
    }

    final backupDir = await getBackupsDirectory();
    final timeStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'backup_manual_$timeStr.db';
    final targetPath = p.join(backupDir.path, fileName);

    final copiedFile = await dbFile.copy(targetPath);
    final size = await copiedFile.length();

    // Registra no histórico do banco
    try {
      final db = await LocalDatabaseHelper.instance.database;
      await db.insert('system_backups', {
        'id': 'bkp_${DateTime.now().millisecondsSinceEpoch}',
        'file_name': fileName,
        'file_path': targetPath,
        'backup_type': 'manual',
        'created_at': DateTime.now().toIso8601String(),
        'file_size_bytes': size,
      });
    } catch (_) {}

    return BackupItem(
      fileName: fileName,
      filePath: targetPath,
      type: 'manual',
      createdAt: DateTime.now(),
      sizeBytes: size,
    );
  }

  /// Lista todos os arquivos de backup salvos no aparelho ordenados do mais recente para o mais antigo
  Future<List<BackupItem>> listBackups() async {
    final backupDir = await getBackupsDirectory();
    final files = backupDir.listSync().whereType<File>().toList();

    final List<BackupItem> list = [];

    for (final file in files) {
      final name = p.basename(file.path);
      if (name.endsWith('.db') || name.endsWith('.json')) {
        final stat = file.statSync();
        final type = name.contains('pre_upgrade')
            ? 'pre_upgrade'
            : (name.endsWith('.json') ? 'json' : 'manual');

        list.add(BackupItem(
          fileName: name,
          filePath: file.path,
          type: type,
          createdAt: stat.modified,
          sizeBytes: stat.size,
        ));
      }
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Restaura o banco de dados a partir de um backup .db selecionado
  Future<bool> restoreDatabaseFromBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) return false;

      // 1. Fecha conexões ativas com o banco
      await LocalDatabaseHelper.instance.close();

      // 2. Localiza o destino
      final dbDir = await getDatabasesPath();
      final targetFile = File(p.join(dbDir, _dbFileName));

      // 3. Sobrescreve o arquivo SQLite
      await backupFile.copy(targetFile.path);

      // 4. Reabre o banco para garantir a integridade
      await LocalDatabaseHelper.instance.database;
      debugPrint('Banco restaurado com sucesso a partir de $backupFilePath');
      return true;
    } catch (e) {
      debugPrint('Erro ao restaurar backup: $e');
      return false;
    }
  }

  /// Exporta todos os dados locais em formato JSON estruturado
  Future<String> exportDataToJson() async {
    final db = await LocalDatabaseHelper.instance.database;

    final users = await db.query('users');
    final accounts = await db.query('accounts');
    final categories = await db.query('categories');
    final transactions = await db.query('transactions');
    final forecasts = await db.query('financial_forecasts');

    final exportMap = {
      'app': 'FinancasLocal',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'users': users,
      'accounts': accounts,
      'categories': categories,
      'transactions': transactions,
      'financial_forecasts': forecasts,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(exportMap);

    // Salva arquivo .json no diretório de backups
    final backupDir = await getBackupsDirectory();
    final timeStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final jsonFile = File(p.join(backupDir.path, 'backup_completo_$timeStr.json'));
    await jsonFile.writeAsString(jsonStr);

    return jsonFile.path;
  }

  /// Exclui um arquivo de backup específico do armazenamento local
  Future<bool> deleteBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      try {
        final db = await LocalDatabaseHelper.instance.database;
        await db.delete('system_backups', where: 'file_path = ?', whereArgs: [filePath]);
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Erro ao excluir backup: $e');
      return false;
    }
  }

  /// Exclui todas as cópias de backup salvas no aparelho
  Future<bool> deleteAllBackups() async {
    try {
      final backupDir = await getBackupsDirectory();
      if (await backupDir.exists()) {
        final files = backupDir.listSync().whereType<File>();
        for (final f in files) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      try {
        final db = await LocalDatabaseHelper.instance.database;
        await db.delete('system_backups');
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Erro ao excluir todos os backups: $e');
      return false;
    }
  }
}

