import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/database/local_database_helper.dart';
import '../models/account_model.dart';

class AccountService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<List<AccountModel>> getAccounts() async {
    final db = await _dbHelper.database;
    final rows = await db.query('accounts', where: 'is_archived = 0', orderBy: 'name ASC');

    return rows.map((row) {
      return AccountModel(
        id: row['id'] as String,
        name: row['name'] as String,
        type: row['type'] as String,
        balance: (row['balance'] as num).toDouble(),
        color: (row['color'] as String?) ?? '#38BDF8',
        organizationId: 'local_org',
        creditLimit: (row['credit_limit'] as num?)?.toDouble(),
        closingDay: row['closing_day'] as int?,
        dueDay: row['due_day'] as int?,
      );
    }).toList();
  }

  Future<bool> createAccount({
    required String name,
    required String type,
    required double balance,
    String? organizationId,
    String color = '#38BDF8',
    double? creditLimit,
    int? closingDay,
    int? dueDay,
  }) async {
    final db = await _dbHelper.database;
    final id = 'acc_${DateTime.now().millisecondsSinceEpoch}';

    final isCreditCard = type.toLowerCase().contains('cart') || type.toLowerCase().contains('credit') ? 1 : 0;

    await db.insert('accounts', {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'initial_balance': balance,
      'color': color,
      'is_credit_card': isCreditCard,
      'credit_limit': creditLimit,
      'closing_day': closingDay,
      'due_day': dueDay,
      'is_archived': 0,
      'user_id': 'local_user_default',
    });

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> updateAccount(
    String id, {
    required String name,
    required String type,
    required double balance,
    String? organizationId,
    String color = '#38BDF8',
    double? creditLimit,
    int? closingDay,
    int? dueDay,
  }) async {
    final db = await _dbHelper.database;
    final isCreditCard = type.toLowerCase().contains('cart') || type.toLowerCase().contains('credit') ? 1 : 0;

    await db.update(
      'accounts',
      {
        'name': name,
        'type': type,
        'balance': balance,
        'color': color,
        'is_credit_card': isCreditCard,
        'credit_limit': creditLimit,
        'closing_day': closingDay,
        'due_day': dueDay,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> deleteAccount(String id) async {
    final db = await _dbHelper.database;
    // Marca como arquivada ou exclui
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
    DataRefreshController.instance.notify();
    return true;
  }
}
