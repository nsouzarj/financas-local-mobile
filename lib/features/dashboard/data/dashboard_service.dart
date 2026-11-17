import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/database/local_database_helper.dart';
import '../../categories/data/category_service.dart';
import '../../transactions/models/transaction_model.dart';
import '../models/dashboard_model.dart';

class DashboardService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<DashboardData> fetchDashboardData({int? month, int? year}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    final monthStr = targetMonth.toString().padLeft(2, '0');
    final filterPrefix = '$targetYear-$monthStr%';

    // 1. Saldo Total em Contas
    final accountsRows = await db.rawQuery('''
      SELECT SUM(CASE WHEN is_credit_card = 1 THEN -balance ELSE balance END) as total 
      FROM accounts WHERE is_archived = 0
    ''');
    final totalBalance = (accountsRows.first['total'] as num?)?.toDouble() ?? 0.0;

    // 2. Receitas e Despesas do Mês
    final incomeRow = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'income' AND date LIKE ?
    ''', [filterPrefix]);
    final monthlyIncome = (incomeRow.first['total'] as num?)?.toDouble() ?? 0.0;

    final expenseRow = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'expense' AND date LIKE ?
    ''', [filterPrefix]);
    final monthlyExpenses = (expenseRow.first['total'] as num?)?.toDouble() ?? 0.0;

    // 3. Transações Recentes do mês selecionado (com JOIN em categorias e contas)
    final recentTxRows = await db.rawQuery('''
      SELECT t.*, c.name as categoryName, c.color as categoryColor, a.name as accountName 
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN accounts a ON t.account_id = a.id
      WHERE t.date LIKE ?
      ORDER BY t.date DESC
      LIMIT 10
    ''', [filterPrefix]);

    final recentTransactions = recentTxRows.map<TransactionModel>((row) {
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

    // 4. Detalhamento por Categoria (Gráfico Rosca de Despesas)
    final breakdownRows = await db.rawQuery('''
      SELECT COALESCE(c.name, 'Outros') as name, 
             COALESCE(c.color, '#38BDF8') as color, 
             SUM(t.amount) as total
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' AND t.date LIKE ?
      GROUP BY c.name, c.color
      ORDER BY total DESC
    ''', [filterPrefix]);

    final categoryBreakdown = breakdownRows.map((row) {
      return CategoryBreakdownItem(
        name: row['name'] as String,
        value: (row['total'] as num).toDouble(),
        color: row['color'] as String,
      );
    }).toList();

    // 5. Contas Pendentes e Alertas de Vencimento
    final alertRows = await db.rawQuery('''
      SELECT f.*, c.name as categoryName 
      FROM financial_forecasts f
      LEFT JOIN categories c ON f.category_id = c.id
      WHERE f.status != 'paid'
      ORDER BY f.due_date ASC
    ''');

    final List<UpcomingAlertItem> upcomingAlerts = [];
    int overdueCount = 0;
    double pendingTotal = 0.0;

    for (final r in alertRows) {
      final dueDateStr = r['due_date'] as String;
      final dueDate = DateTime.tryParse(dueDateStr) ?? now;
      final amount = (r['amount'] as num).toDouble();
      final reminderDays = (r['reminder_days'] as int?) ?? 30;

      pendingTotal += amount;
      final diffDays = dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays < 0) {
        overdueCount++;
      }

      if (diffDays <= reminderDays) {
        upcomingAlerts.add(UpcomingAlertItem(
          id: r['id'] as String,
          description: r['description'] as String,
          amount: amount,
          dueDate: dueDate,
          reminderDays: reminderDays,
          categoryName: r['categoryName'] as String?,
        ));
      }
    }

    final pendingBills = PendingBillsSummary(
      count: alertRows.length,
      total: pendingTotal,
      overdueCount: overdueCount,
    );

    return DashboardData(
      totalBalance: totalBalance,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      recentTransactions: recentTransactions,
      categoryBreakdown: categoryBreakdown,
      pendingBills: pendingBills,
      upcomingAlerts: upcomingAlerts,
    );
  }

  Future<List<Map<String, dynamic>>> fetchAccounts() async {
    final db = await _dbHelper.database;
    return await db.query('accounts', where: 'is_archived = 0', orderBy: 'name ASC');
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> list =
        await db.query('categories', orderBy: 'name ASC');
    if (list.isEmpty) {
      await CategoryService().getCategories();
      list = await db.query('categories', orderBy: 'name ASC');
    }
    return list;
  }

  Future<bool> createTransaction({
    required String accountId,
    required String categoryId,
    required String description,
    required double amount,
    required String type,
    required DateTime date,
    required String status,
    int installments = 1,
    int? reminderDays,
    DateTime? dueDate,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final dueStr = dueDate != null
        ? "${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}"
        : dateStr;

    if (status == 'planned') {
      final id = 'plan_${DateTime.now().millisecondsSinceEpoch}';
      await db.insert('financial_forecasts', {
        'id': id,
        'description': description,
        'amount': amount,
        'type': type,
        'due_date': dueStr,
        'account_id': accountId,
        'category_id': categoryId.isEmpty ? null : categoryId,
        'reminder_days': reminderDays ?? 7,
        'status': 'pending',
        'user_id': 'local_user_default',
      });
      DataRefreshController.instance.notify();
      return true;
    }

    final isPaid = status == 'paid' ? 1 : 0;
    final id = 'tx_${DateTime.now().millisecondsSinceEpoch}';

    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': id,
        'description': description,
        'amount': amount,
        'date': dateStr,
        'type': type,
        'category_id': categoryId.isEmpty ? null : categoryId,
        'account_id': accountId,
        'is_paid': isPaid,
        'notes': notes,
        'user_id': 'local_user_default',
      });

      // Se foi pago, atualiza saldo da conta imediatamente
      if (isPaid == 1) {
        final delta = type == 'income' ? amount : -amount;
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [delta, accountId],
        );
      }
    });

    DataRefreshController.instance.notify();
    return true;
  }
}
