import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/database/local_database_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/models/transaction_model.dart';

class PlanningService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<List<TransactionModel>> getPlannedTransactions({
    String? startDate,
    String? endDate,
  }) async {
    final db = await _dbHelper.database;

    final StringBuffer whereClause = StringBuffer("f.status != 'paid'");
    final List<dynamic> whereArgs = [];

    if (startDate != null && startDate.isNotEmpty) {
      whereClause.write(' AND f.due_date >= ?');
      whereArgs.add(startDate);
    }

    if (endDate != null && endDate.isNotEmpty) {
      whereClause.write(' AND f.due_date <= ?');
      whereArgs.add(endDate);
    }

    final query = '''
      SELECT f.*, c.name as categoryName, c.color as categoryColor, a.name as accountName 
      FROM financial_forecasts f
      LEFT JOIN categories c ON f.category_id = c.id
      LEFT JOIN accounts a ON f.account_id = a.id
      WHERE $whereClause
      ORDER BY f.due_date ASC
    ''';

    final rows = await db.rawQuery(query, whereArgs);

    return rows.map<TransactionModel>((row) {
      return TransactionModel(
        id: row['id'] as String,
        description: row['description'] as String,
        amount: (row['amount'] as num).toDouble(),
        date: DateTime.parse(row['due_date'] as String),
        dueDate: DateTime.parse(row['due_date'] as String),
        type: row['type'] as String,
        categoryId: row['category_id'] as String?,
        categoryName: row['categoryName'] as String?,
        categoryColor: row['categoryColor'] as String?,
        accountId: row['account_id'] as String?,
        accountName: row['accountName'] as String?,
        status: 'planned',
        reminderDays: (row['reminder_days'] as int?) ?? 7,
      );
    }).toList();
  }

  Future<bool> createPlannedTransaction({
    required String description,
    required double amount,
    required String type,
    required DateTime dueDate,
    required String accountId,
    required String categoryId,
    int reminderDays = 7,
  }) async {
    final db = await _dbHelper.database;
    final id = 'plan_${DateTime.now().millisecondsSinceEpoch}';
    final dateStr =
        "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

    await db.insert('financial_forecasts', {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'due_date': dateStr,
      'status': 'pending',
      'account_id': accountId,
      'category_id': categoryId.isEmpty ? null : categoryId,
      'reminder_days': reminderDays,
      'user_id': 'local_user_default',
    });

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> updatePlannedTransaction({
    required String id,
    required String description,
    required double amount,
    required String type,
    required DateTime dueDate,
    required String accountId,
    required String categoryId,
    int reminderDays = 7,
  }) async {
    final db = await _dbHelper.database;
    final dateStr =
        "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}";

    await db.update(
      'financial_forecasts',
      {
        'description': description,
        'amount': amount,
        'type': type,
        'due_date': dateStr,
        'account_id': accountId,
        'category_id': categoryId.isEmpty ? null : categoryId,
        'reminder_days': reminderDays,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    DataRefreshController.instance.notify();
    return true;
  }

  /// Baixa a conta planejada com suporte a valor parcial, alteração de conta/categoria e agendamento de restante
  Future<bool> settlePlannedTransaction({
    required String plannedId,
    required double paidAmount,
    required DateTime paymentDate,
    required String accountId,
    required String categoryId,
    required String description,
    required String type,
    String? notes,
    required double originalAmount,
    required DateTime originalDueDate,
    required String remainderAction, // 'next_month', 'keep_current', 'none'
  }) async {
    final db = await _dbHelper.database;
    final paymentDateStr = CurrencyFormatter.formatDateToApi(paymentDate);

    await db.transaction((txn) async {
      // 1. Cria o lançamento real confirmado no extrato (transactions)
      final newTxId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
      await txn.insert('transactions', {
        'id': newTxId,
        'description': description,
        'amount': paidAmount,
        'date': paymentDateStr,
        'type': type,
        'category_id': categoryId.isEmpty ? null : categoryId,
        'account_id': accountId,
        'is_paid': 1,
        'notes': notes,
        'user_id': 'local_user_default',
      });

      // 2. Atualiza o saldo real da conta bancária
      final delta = type == 'income' ? paidAmount : -paidAmount;
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [delta, accountId],
      );

      // 3. Trata a previsão do planejamento (financial_forecasts)
      final difference = originalAmount - paidAmount;
      if (difference > 0.009 && remainderAction == 'next_month') {
        // Marca a previsão atual como paga
        await txn.update(
          'financial_forecasts',
          {'status': 'paid'},
          where: 'id = ?',
          whereArgs: [plannedId],
        );

        // Gera a nova previsão no próximo mês para o valor restante
        final nextMonth = originalDueDate.month == 12 ? 1 : originalDueDate.month + 1;
        final nextYear = originalDueDate.month == 12 ? originalDueDate.year + 1 : originalDueDate.year;
        final maxDaysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final targetDay = originalDueDate.day > maxDaysInNextMonth ? maxDaysInNextMonth : originalDueDate.day;
        final nextDue = DateTime(nextYear, nextMonth, targetDay);
        final nextDueStr = CurrencyFormatter.formatDateToApi(nextDue);

        final nextPlanId = 'plan_${DateTime.now().millisecondsSinceEpoch + 10}';
        await txn.insert('financial_forecasts', {
          'id': nextPlanId,
          'description': '$description (Restante)',
          'amount': difference,
          'due_date': nextDueStr,
          'type': type,
          'category_id': categoryId.isEmpty ? null : categoryId,
          'account_id': accountId,
          'reminder_days': 7,
          'status': 'pending',
          'user_id': 'local_user_default',
        });
      } else if (difference > 0.009 && remainderAction == 'keep_current') {
        // Mantém a previsão atual com o valor restante em aberto neste mês
        await txn.update(
          'financial_forecasts',
          {
            'amount': difference,
            'status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [plannedId],
        );
      } else {
        // Quitou tudo ou desconsiderou diferença
        await txn.update(
          'financial_forecasts',
          {'status': 'paid'},
          where: 'id = ?',
          whereArgs: [plannedId],
        );
      }
    });

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> confirmPayment(TransactionModel tx) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr =
        "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    await db.transaction((txn) async {
      // 1. Marca como pago no planejamento
      await txn.update(
        'financial_forecasts',
        {'status': 'paid'},
        where: 'id = ?',
        whereArgs: [tx.id],
      );

      // 2. Cria lançamento real no extrato
      final newTxId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
      await txn.insert('transactions', {
        'id': newTxId,
        'description': tx.description,
        'amount': tx.amount,
        'date': todayStr,
        'type': tx.type,
        'category_id': tx.categoryId,
        'account_id': tx.accountId,
        'is_paid': 1,
        'user_id': 'local_user_default',
      });

      // 3. Atualiza saldo da conta
      if (tx.accountId != null && tx.accountId!.isNotEmpty) {
        final delta = tx.isIncome ? tx.amount : -tx.amount;
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [delta, tx.accountId],
        );
      }
    });

    DataRefreshController.instance.notify();
    return true;
  }

  Future<bool> deletePlanned(String id) async {
    final db = await _dbHelper.database;
    await db.delete('financial_forecasts', where: 'id = ?', whereArgs: [id]);
    DataRefreshController.instance.notify();
    return true;
  }

  /// Calcula a data equivalente no próximo mês ajustando sábado/domingo para segunda-feira (dia útil).
  static DateTime calculateNextMonthBusinessDate(DateTime source) {
    final nextMonth = source.month == 12 ? 1 : source.month + 1;
    final nextYear = source.month == 12 ? source.year + 1 : source.year;
    final maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
    final targetDay = source.day > maxDays ? maxDays : source.day;
    var target = DateTime(nextYear, nextMonth, targetDay);

    if (target.weekday == DateTime.saturday) {
      target = target.add(const Duration(days: 2));
    } else if (target.weekday == DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  Future<DateTime?> copyToNextMonth(TransactionModel tx) async {
    final targetDate = calculateNextMonthBusinessDate(tx.dueDate ?? tx.date);
    final ok = await createPlannedTransaction(
      description: tx.description,
      amount: tx.amount,
      type: tx.type,
      dueDate: targetDate,
      accountId: tx.accountId ?? '',
      categoryId: tx.categoryId ?? '',
      reminderDays: tx.reminderDays ?? 7,
    );
    return ok ? targetDate : null;
  }

  Future<int> copyBatchToNextMonth(List<TransactionModel> items) async {
    if (items.isEmpty) return 0;
    final db = await _dbHelper.database;
    final baseMicros = DateTime.now().microsecondsSinceEpoch;
    int copied = 0;

    await db.transaction((txn) async {
      for (int i = 0; i < items.length; i++) {
        final tx = items[i];
        final targetDate = calculateNextMonthBusinessDate(tx.dueDate ?? tx.date);
        final dateStr = CurrencyFormatter.formatDateToApi(targetDate);

        await txn.insert('financial_forecasts', {
          'id': 'plan_${baseMicros}_$i',
          'description': tx.description,
          'amount': tx.amount,
          'type': tx.type,
          'due_date': dateStr,
          'status': 'pending',
          'account_id': (tx.accountId != null && tx.accountId!.isNotEmpty) ? tx.accountId : null,
          'category_id': (tx.categoryId != null && tx.categoryId!.isNotEmpty) ? tx.categoryId : null,
          'reminder_days': tx.reminderDays ?? 7,
          'user_id': 'local_user_default',
        });
        copied++;
      }
    });

    DataRefreshController.instance.notify();
    return copied;
  }
}
