import '../../transactions/models/transaction_model.dart';

class CategoryBreakdownItem {
  final String name;
  final double value;
  final String color;

  CategoryBreakdownItem({
    required this.name,
    required this.value,
    required this.color,
  });

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      name: json['name']?.toString() ?? 'Outros',
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0.0,
      color: json['color']?.toString() ?? '#38BDF8',
    );
  }
}

class PendingBillsSummary {
  final int count;
  final double total;
  final int overdueCount;

  PendingBillsSummary({
    required this.count,
    required this.total,
    required this.overdueCount,
  });

  factory PendingBillsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PendingBillsSummary(count: 0, total: 0.0, overdueCount: 0);
    }
    return PendingBillsSummary(
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      overdueCount: int.tryParse(json['overdueCount']?.toString() ?? '0') ?? 0,
    );
  }
}

class UpcomingAlertItem {
  final String id;
  final String description;
  final double amount;
  final DateTime dueDate;
  final int reminderDays;
  final String? categoryName;

  UpcomingAlertItem({
    required this.id,
    required this.description,
    required this.amount,
    required this.dueDate,
    required this.reminderDays,
    this.categoryName,
  });

  factory UpcomingAlertItem.fromJson(Map<String, dynamic> json) {
    return UpcomingAlertItem(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? 'Previsão',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      reminderDays: int.tryParse(json['reminderDays']?.toString() ?? '7') ?? 7,
      categoryName: json['categoryName']?.toString(),
    );
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }
}

class DashboardData {
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final List<TransactionModel> recentTransactions;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final PendingBillsSummary pendingBills;
  final List<UpcomingAlertItem> upcomingAlerts;

  DashboardData({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.recentTransactions,
    required this.categoryBreakdown,
    required this.pendingBills,
    required this.upcomingAlerts,
  });

  double get netBalance => monthlyIncome - monthlyExpenses;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final list = json['recentTransactions'] as List? ?? [];
    final catList = json['categoryBreakdown'] as List? ?? [];
    final alertsList = json['upcomingAlerts'] as List? ?? [];

    return DashboardData(
      totalBalance: double.tryParse(json['totalBalance']?.toString() ?? '0') ?? 0.0,
      monthlyIncome: double.tryParse(json['monthlyIncome']?.toString() ?? json['income']?.toString() ?? '0') ?? 0.0,
      monthlyExpenses: double.tryParse(json['monthlyExpenses']?.toString() ?? json['expenses']?.toString() ?? '0') ?? 0.0,
      recentTransactions: list.map((item) => TransactionModel.fromJson(item)).toList(),
      categoryBreakdown: catList.map((item) => CategoryBreakdownItem.fromJson(item)).toList(),
      pendingBills: PendingBillsSummary.fromJson(json['pendingBills'] as Map<String, dynamic>?),
      upcomingAlerts: alertsList.map((item) => UpcomingAlertItem.fromJson(item)).toList(),
    );
  }
}
