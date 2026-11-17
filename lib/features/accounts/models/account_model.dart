class AccountModel {
  final String id;
  final String name;
  final String type; // 'Checking', 'Savings', 'Credit Card', 'Investment', 'Cash', etc.
  final double balance;
  final String color;
  final String? organizationId;
  final double? creditLimit;
  final int? closingDay;
  final int? dueDay;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.color,
    this.organizationId,
    this.creditLimit,
    this.closingDay,
    this.dueDay,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sem nome',
      type: json['type']?.toString() ?? 'Checking',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      color: json['color']?.toString() ?? '#38BDF8',
      organizationId: json['organizationId']?.toString(),
      creditLimit: json['creditLimit'] != null ? double.tryParse(json['creditLimit'].toString()) : null,
      closingDay: json['closingDay'] != null ? int.tryParse(json['closingDay'].toString()) : null,
      dueDay: json['dueDay'] != null ? int.tryParse(json['dueDay'].toString()) : null,
    );
  }

  bool get isCreditCard {
    final t = type.toLowerCase().trim();
    return t == 'credit' || t == 'credit card' || t == 'credit_card' || t.contains('cart');
  }

  String get typeLabel {
    final t = type.toLowerCase().trim();
    if (t == 'checking' || t.contains('corrente')) {
      return 'Conta Corrente';
    } else if (t == 'savings' || t.contains('poup')) {
      return 'Conta Poupança';
    } else if (t == 'credit' || t == 'credit card' || t == 'credit_card' || t.contains('cart')) {
      return 'Cartão de Crédito';
    } else if (t == 'investment' || t.contains('invest')) {
      return 'Investimentos';
    } else if (t == 'cash' || t.contains('dinh') || t.contains('carteira') || t.contains('espécie')) {
      return 'Carteira (Dinheiro)';
    }
    if (type.trim().isNotEmpty) {
      return type;
    }
    return 'Conta Corrente';
  }
}

