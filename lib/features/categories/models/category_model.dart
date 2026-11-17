class CategoryModel {
  final String id;
  final String name;
  final String type; // 'income', 'expense', or 'both'
  final String color;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Sem nome',
      type: json['type']?.toString().toLowerCase() ?? 'expense',
      color: json['color']?.toString() ?? '#38BDF8',
    );
  }

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isBoth => type == 'both';
}

