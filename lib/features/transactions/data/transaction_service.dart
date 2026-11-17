import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/database/local_database_helper.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<List<TransactionModel>> getTransactions({
    String? accountId,
    String? type,
    String? search,
    String? startDate,
    String? endDate,
    String? statusFilter,
  }) async {
    final db = await _dbHelper.database;

    final StringBuffer whereClause = StringBuffer('1=1');
    final List<dynamic> whereArgs = [];

    if (accountId != null && accountId.isNotEmpty) {
      whereClause.write(' AND t.account_id = ?');
      whereArgs.add(accountId);
    }

    if (type != null && type != 'all') {
      whereClause.write(' AND t.type = ?');
      whereArgs.add(type);
    }

    if (startDate != null && startDate.isNotEmpty) {
      whereClause.write(' AND substr(t.date, 1, 10) >= ?');
      whereArgs.add(startDate.length >= 10 ? startDate.substring(0, 10) : startDate);
    }

    if (endDate != null && endDate.isNotEmpty) {
      whereClause.write(' AND substr(t.date, 1, 10) <= ?');
      whereArgs.add(endDate.length >= 10 ? endDate.substring(0, 10) : endDate);
    }

    if (search != null && search.trim().isNotEmpty) {
      whereClause.write(' AND (t.description LIKE ? OR c.name LIKE ? OR a.name LIKE ?)');
      final term = '%${search.trim()}%';
      whereArgs.addAll([term, term, term]);
    }

    final query = '''
      SELECT t.*, c.name as categoryName, c.color as categoryColor, a.name as accountName 
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''';

    final rows = await db.rawQuery(query, whereArgs);

    return rows.map<TransactionModel>((row) {
      return TransactionModel(
        id: row['id'] as String,
        description: row['description'] as String,
        amount: (row['amount'] as num).toDouble(),
        date: DateTime.parse(row['date'] as String),
        type: row['type'] as String,
        categoryId: row['category_id'] as String?,
        categoryName: row['categoryName'] as String?,
        categoryColor: row['categoryColor'] as String?,
        accountId: row['account_id'] as String?,
        accountName: row['accountName'] as String?,
        status: ((row['is_paid'] as int?) == 1) ? 'paid' : 'pending',
      );
    }).toList();
  }

  Future<bool> updateTransaction({
    required String id,
    required String description,
    required double amount,
    required String type,
    required DateTime date,
    required String status,
    required String accountId,
    required String categoryId,
    int? reminderDays,
    DateTime? dueDate,
  }) async {
    final db = await _dbHelper.database;
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    await db.transaction((txn) async {
      // 1. Obtém a transação antiga para reverter o saldo se estava paga
      final oldTxRows = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (oldTxRows.isNotEmpty) {
        final oldRow = oldTxRows.first;
        final wasPaid = (oldRow['is_paid'] as int?) == 1;
        if (wasPaid) {
          final oldAmount = (oldRow['amount'] as num).toDouble();
          final oldType = oldRow['type'] as String;
          final oldAccId = oldRow['account_id'] as String;

          // Reverte saldo anterior
          final oldRevert = oldType == 'income' ? -oldAmount : oldAmount;
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ? WHERE id = ?',
            [oldRevert, oldAccId],
          );
        }
      }

      final isNowPaid = status == 'paid';

      // 2. Atualiza os dados
      await txn.update(
        'transactions',
        {
          'description': description,
          'amount': amount,
          'type': type,
          'date': dateStr,
          'account_id': accountId,
          'category_id': categoryId.isEmpty ? null : categoryId,
          'is_paid': isNowPaid ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      // 3. Aplica o novo saldo na conta se estiver paga
      if (isNowPaid) {
        final newDelta = type == 'income' ? amount : -amount;
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [newDelta, accountId],
        );
      }
    });

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> deleteTransaction(String id) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final oldTxRows = await txn.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (oldTxRows.isNotEmpty) {
        final oldRow = oldTxRows.first;
        final wasPaid = (oldRow['is_paid'] as int?) == 1;
        if (wasPaid) {
          final oldAmount = (oldRow['amount'] as num).toDouble();
          final oldType = oldRow['type'] as String;
          final oldAccId = oldRow['account_id'] as String;

          // Reverte saldo
          final revertDelta = oldType == 'income' ? -oldAmount : oldAmount;
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ? WHERE id = ?',
            [revertDelta, oldAccId],
          );
        }
      }

      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });

    DataRefreshController.instance.notify();
    return true;
  }
}
