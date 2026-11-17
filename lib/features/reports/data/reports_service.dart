import 'package:intl/intl.dart';
import '../../../core/database/local_database_helper.dart';

class CategoryReportItem {
  final String id;
  final String name;
  final String color;
  final double total;
  final int count;
  final double percentage;

  const CategoryReportItem({
    required this.id,
    required this.name,
    required this.color,
    required this.total,
    required this.count,
    required this.percentage,
  });
}

class MonthEvolutionItem {
  final String label;
  final int year;
  final int month;
  final double income;
  final double expense;

  const MonthEvolutionItem({
    required this.label,
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });

  double get net => income - expense;
}

class AccountReportItem {
  final String id;
  final String name;
  final String type;
  final String color;
  final double balance;
  final double percentage;

  const AccountReportItem({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.balance,
    required this.percentage,
  });

  String get typeLabel {
    final t = type.toLowerCase().trim();
    if (t == 'checking' || t.contains('corrente')) return 'Conta Corrente';
    if (t == 'savings' || t.contains('poup')) return 'Poupança';
    if (t == 'credit' || t == 'credit card' || t == 'credit_card' || t.contains('cart')) return 'Cartão de Crédito';
    if (t == 'investment' || t.contains('invest')) return 'Investimentos';
    if (t == 'cash' || t.contains('dinh') || t.contains('carteira') || t.contains('espécie')) return 'Carteira (Dinheiro)';
    if (type.trim().isNotEmpty) return type;
    return 'Conta Corrente';
  }
}

class ReportSummary {
  final String periodLabel;
  final double totalIncome;
  final double totalExpense;
  final double netBalance;
  final double savingsRate; // 0 a 100%
  final List<MonthEvolutionItem> evolution;
  final List<CategoryReportItem> expenseCategories;
  final List<CategoryReportItem> incomeCategories;
  final List<AccountReportItem> accounts;

  const ReportSummary({
    required this.periodLabel,
    required this.totalIncome,
    required this.totalExpense,
    required this.netBalance,
    required this.savingsRate,
    required this.evolution,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
  });
}

enum ReportPeriod {
  currentMonth,
  last3Months,
  last6Months,
  currentYear,
}

class ReportsService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<ReportSummary> getReport(ReportPeriod period, {DateTime? customDate}) async {
    final db = await _dbHelper.database;
    final now = customDate ?? DateTime.now();

    DateTime startDate;
    DateTime endDate;
    String periodLabel;

    switch (period) {
      case ReportPeriod.currentMonth:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        periodLabel = DateFormat('MMMM yyyy', 'pt_BR').format(now);
        break;
      case ReportPeriod.last3Months:
        startDate = DateTime(now.year, now.month - 2, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        periodLabel = 'Últimos 3 Meses';
        break;
      case ReportPeriod.last6Months:
        startDate = DateTime(now.year, now.month - 5, 1);
        endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        periodLabel = 'Últimos 6 Meses';
        break;
      case ReportPeriod.currentYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        periodLabel = 'Ano de ${now.year}';
        break;
    }

    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    // 1. Totais Gerais de Receitas e Despesas
    final totalIncomeRow = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'income' AND date >= ? AND date <= ?
    ''', [startStr, endStr]);
    final totalIncome = (totalIncomeRow.first['total'] as num?)?.toDouble() ?? 0.0;

    final totalExpenseRow = await db.rawQuery('''
      SELECT SUM(amount) as total FROM transactions 
      WHERE type = 'expense' AND date >= ? AND date <= ?
    ''', [startStr, endStr]);
    final totalExpense = (totalExpenseRow.first['total'] as num?)?.toDouble() ?? 0.0;

    final netBalance = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0
        ? ((netBalance / totalIncome) * 100).clamp(0.0, 100.0)
        : 0.0;

    // 2. Evolução Mês a Mês
    final List<MonthEvolutionItem> evolution = [];
    int monthsToIterate = period == ReportPeriod.currentMonth
        ? 1
        : (period == ReportPeriod.last3Months
            ? 3
            : (period == ReportPeriod.last6Months ? 6 : 12));

    for (int i = monthsToIterate - 1; i >= 0; i--) {
      final mDate = DateTime(now.year, now.month - i, 1);
      final mPrefix = DateFormat('yyyy-MM').format(mDate);
      final mLabel = DateFormat('MMM', 'pt_BR').format(mDate).toUpperCase();

      final incRow = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND date LIKE '$mPrefix%'",
      );
      final expRow = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND date LIKE '$mPrefix%'",
      );

      final mInc = (incRow.first['total'] as num?)?.toDouble() ?? 0.0;
      final mExp = (expRow.first['total'] as num?)?.toDouble() ?? 0.0;

      evolution.add(MonthEvolutionItem(
        label: mLabel,
        year: mDate.year,
        month: mDate.month,
        income: mInc,
        expense: mExp,
      ));
    }

    // 3. Despesas por Categoria
    final expenseCatRows = await db.rawQuery('''
      SELECT COALESCE(c.id, 'outros') as id,
             COALESCE(c.name, 'Outros') as name, 
             COALESCE(c.color, '#EF4444') as color, 
             SUM(t.amount) as total,
             COUNT(t.id) as count
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' AND t.date >= ? AND t.date <= ?
      GROUP BY c.id, c.name, c.color
      ORDER BY total DESC
    ''', [startStr, endStr]);

    final List<CategoryReportItem> expenseCategories = expenseCatRows.map((r) {
      final total = (r['total'] as num).toDouble();
      final count = (r['count'] as num).toInt();
      final pct = totalExpense > 0 ? (total / totalExpense) * 100 : 0.0;
      return CategoryReportItem(
        id: r['id'] as String,
        name: r['name'] as String,
        color: r['color'] as String,
        total: total,
        count: count,
        percentage: pct,
      );
    }).toList();

    // 4. Receitas por Categoria
    final incomeCatRows = await db.rawQuery('''
      SELECT COALESCE(c.id, 'outros') as id,
             COALESCE(c.name, 'Outros') as name, 
             COALESCE(c.color, '#10B981') as color, 
             SUM(t.amount) as total,
             COUNT(t.id) as count
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'income' AND t.date >= ? AND t.date <= ?
      GROUP BY c.id, c.name, c.color
      ORDER BY total DESC
    ''', [startStr, endStr]);

    final List<CategoryReportItem> incomeCategories = incomeCatRows.map((r) {
      final total = (r['total'] as num).toDouble();
      final count = (r['count'] as num).toInt();
      final pct = totalIncome > 0 ? (total / totalIncome) * 100 : 0.0;
      return CategoryReportItem(
        id: r['id'] as String,
        name: r['name'] as String,
        color: r['color'] as String,
        total: total,
        count: count,
        percentage: pct,
      );
    }).toList();

    // 5. Distribuição de Saldo por Conta
    final accountsRows = await db.query('accounts', where: 'is_archived = 0', orderBy: 'balance DESC');
    final totalPositiveBalance = accountsRows
        .map((r) => (r['balance'] as num).toDouble())
        .where((b) => b > 0)
        .fold<double>(0.0, (s, b) => s + b);

    final List<AccountReportItem> accounts = accountsRows.map((r) {
      final bal = (r['balance'] as num).toDouble();
      final pct = totalPositiveBalance > 0 && bal > 0 ? (bal / totalPositiveBalance) * 100 : 0.0;
      return AccountReportItem(
        id: r['id'] as String,
        name: r['name'] as String,
        type: r['type'] as String,
        color: (r['color'] as String?) ?? '#38BDF8',
        balance: bal,
        percentage: pct,
      );
    }).toList();

    return ReportSummary(
      periodLabel: periodLabel,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netBalance: netBalance,
      savingsRate: savingsRate,
      evolution: evolution,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      accounts: accounts,
    );
  }
}

