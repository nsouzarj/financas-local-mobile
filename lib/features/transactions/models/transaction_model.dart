class TransactionModel {
  final String id;
  final String description;
  final double amount;
  final String type; // 'income' ou 'expense'
  final DateTime date;
  final String status; // 'paid', 'pending', ou 'planned'
  final String? accountId;
  final String? accountName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final DateTime? dueDate;
  final int? reminderDays;

  TransactionModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.status,
    this.accountId,
    this.accountName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.dueDate,
    this.reminderDays,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      description: json['description']?.toString() ?? 'Sem descrição',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      type: json['type']?.toString().toLowerCase() ?? 'expense',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      accountId: json['accountId']?.toString(),
      accountName: json['accountName']?.toString(),
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName']?.toString(),
      categoryColor: json['categoryColor']?.toString(),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      reminderDays: json['reminderDays'] != null ? int.tryParse(json['reminderDays'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson({String? organizationId}) {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'type': type,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'status': status,
      'accountId': accountId,
      'categoryId': categoryId,
      if (organizationId != null) 'organizationId': organizationId,
      if (dueDate != null)
        'due_date': '${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
      if (reminderDays != null) 'reminderDays': reminderDays,
    };
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isPlanned => status == 'planned';
}
