import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'backup_service.dart';

class LocalDatabaseHelper {
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._internal();
  LocalDatabaseHelper._internal();

  static const String _dbName = 'financas_local.db';
  static const int _dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // Garante suporte a chaves estrangeiras
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onOpen(Database db) async {
    // Garante que colunas adicionadas em revisões existam mesmo em bancos criados anteriormente
    try {
      await db.execute("ALTER TABLE users ADD COLUMN workspace_name TEXT DEFAULT 'Finanças Pessoais'");
    } catch (_) {
      // Coluna já existe
    }

    // Migração de sanitização de rótulos de contas legadas em inglês
    try {
      await db.rawUpdate("UPDATE accounts SET type = 'Conta Corrente' WHERE LOWER(type) IN ('checking', 'checking account')");
      await db.rawUpdate("UPDATE accounts SET type = 'Conta Poupança' WHERE LOWER(type) IN ('savings', 'savings account')");
      await db.rawUpdate("UPDATE accounts SET type = 'Cartão de Crédito' WHERE LOWER(type) IN ('credit', 'credit card', 'credit_card')");
      await db.rawUpdate("UPDATE accounts SET type = 'Investimentos' WHERE LOWER(type) IN ('investment', 'investments')");
      await db.rawUpdate("UPDATE accounts SET type = 'Carteira (Dinheiro)' WHERE LOWER(type) IN ('cash', 'carteira', 'dinheiro')");
    } catch (_) {
      // Falha silenciosa caso tabela não exista ou erro
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Criando tabelas do banco local SQLite (v$version)...');

    // 1. Tabela de Usuários / Perfil Local
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        workspace_name TEXT DEFAULT 'Finanças Pessoais',
        password_hash TEXT,
        biometrics_enabled INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Tabela de Contas e Cartões
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL DEFAULT 0.0,
        initial_balance REAL DEFAULT 0.0,
        color TEXT,
        icon TEXT,
        is_credit_card INTEGER DEFAULT 0,
        credit_limit REAL DEFAULT 0.0,
        closing_day INTEGER,
        due_day INTEGER,
        is_archived INTEGER DEFAULT 0,
        user_id TEXT NOT NULL
      )
    ''');

    // 3. Tabela de Categorias
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT,
        icon TEXT,
        user_id TEXT NOT NULL
      )
    ''');

    // 4. Tabela de Transações / Extrato
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT,
        account_id TEXT NOT NULL,
        destination_account_id TEXT,
        is_paid INTEGER DEFAULT 1,
        notes TEXT,
        payment_method TEXT,
        installments INTEGER DEFAULT 1,
        installment_number INTEGER DEFAULT 1,
        parent_id TEXT,
        user_id TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 5. Tabela de Previsões / Planejamento
    await db.execute('''
      CREATE TABLE financial_forecasts (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        amount REAL NOT NULL,
        due_date TEXT NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT,
        account_id TEXT,
        status TEXT DEFAULT 'pending',
        reminder_days INTEGER DEFAULT 30,
        user_id TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL
      )
    ''');

    // 6. Tabela de Histórico de Backups
    await db.execute('''
      CREATE TABLE system_backups (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        backup_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        file_size_bytes INTEGER NOT NULL
      )
    ''');

    // Carga Inicial (Seed) de dados essenciais para o usuário usar imediatamente
    await _seedInitialData(db);
  }

  /// REQUISITO CRÍTICO: Sempre fazer backup antes de qualquer atualização de versão!
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('GATILHO DE ATUALIZAÇÃO DETECTADO (v$oldVersion -> v$newVersion)!');
    debugPrint('Executando backup de segurança preventivo obrigatório antes de atualizar...');

    try {
      await BackupService.instance.createPreUpdateBackup(oldVersion: oldVersion, newVersion: newVersion);
      debugPrint('Backup pré-atualização concluído com sucesso!');
    } catch (e) {
      debugPrint('Aviso: Falha ao gerar backup pré-atualização: $e');
    }

    // Exemplo de futuras migrações condicionais:
    // if (oldVersion < 2) { ... }
  }

  Future<void> _seedInitialData(Database db) async {
    const defaultUserId = 'local_user_default';
    final nowIso = DateTime.now().toIso8601String();

    // 1. Usuário Padrão
    await db.insert('users', {
      'id': defaultUserId,
      'name': 'Usuário Principal',
      'email': 'usuario@financas.local',
      'workspace_name': 'Finanças Pessoais',
      'password_hash': null,
      'biometrics_enabled': 0,
      'created_at': nowIso,
    });

    // 2. Contas Padrão
    await db.insert('accounts', {
      'id': 'acc_carteira',
      'name': 'Carteira (Dinheiro)',
      'type': 'Dinheiro',
      'balance': 0.0,
      'initial_balance': 0.0,
      'color': '#10B981',
      'icon': 'Wallet',
      'is_credit_card': 0,
      'credit_limit': 0.0,
      'is_archived': 0,
      'user_id': defaultUserId,
    });

    await db.insert('accounts', {
      'id': 'acc_corrente',
      'name': 'Conta Corrente',
      'type': 'Conta Corrente',
      'balance': 0.0,
      'initial_balance': 0.0,
      'color': '#38BDF8',
      'icon': 'Building2',
      'is_credit_card': 0,
      'credit_limit': 0.0,
      'is_archived': 0,
      'user_id': defaultUserId,
    });

    // 3. Categorias de Despesas Padrão
    final defaultExpenseCategories = [
      {'id': 'cat_alim', 'name': 'Alimentação', 'color': '#EF4444', 'icon': 'Utensils'},
      {'id': 'cat_transp', 'name': 'Transporte', 'color': '#3B82F6', 'icon': 'Car'},
      {'id': 'cat_moradia', 'name': 'Moradia', 'color': '#10B981', 'icon': 'Home'},
      {'id': 'cat_lazer', 'name': 'Lazer', 'color': '#F59E0B', 'icon': 'Gamepad'},
      {'id': 'cat_saude', 'name': 'Saúde', 'color': '#F43F5E', 'icon': 'HeartPulse'},
      {'id': 'cat_educacao', 'name': 'Educação', 'color': '#06B6D4', 'icon': 'GraduationCap'},
      {'id': 'cat_outros', 'name': 'Outros', 'color': '#A8A29E', 'icon': 'Tag'},
    ];

    for (final c in defaultExpenseCategories) {
      await db.insert('categories', {
        'id': c['id'],
        'name': c['name'],
        'type': 'expense',
        'color': c['color'],
        'icon': c['icon'],
        'user_id': defaultUserId,
      });
    }

    // 4. Categorias de Receitas Padrão
    final defaultIncomeCategories = [
      {'id': 'cat_salario', 'name': 'Salário', 'color': '#10B981', 'icon': 'Wallet'},
      {'id': 'cat_invest', 'name': 'Investimentos', 'color': '#06B6D4', 'icon': 'TrendingUp'},
      {'id': 'cat_rendim', 'name': 'Rendimentos', 'color': '#14B8A6', 'icon': 'DollarSign'},
      {'id': 'cat_outras_rec', 'name': 'Outras Receitas', 'color': '#3B82F6', 'icon': 'PlusCircle'},
    ];

    for (final c in defaultIncomeCategories) {
      await db.insert('categories', {
        'id': c['id'],
        'name': c['name'],
        'type': 'income',
        'color': c['color'],
        'icon': c['icon'],
        'user_id': defaultUserId,
      });
    }

    debugPrint('Carga inicial de contas e categorias locais inserida com sucesso.');
  }

  /// Fecha a conexão com o banco com segurança
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

