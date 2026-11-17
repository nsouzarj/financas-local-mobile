import '../../../core/database/local_database_helper.dart';
import '../models/category_model.dart';

class CategoryService {
  final LocalDatabaseHelper _dbHelper = LocalDatabaseHelper.instance;

  Future<List<CategoryModel>> getCategories() async {
    final db = await _dbHelper.database;
    List<Map<String, dynamic>> rows =
        await db.query('categories', orderBy: 'name ASC');

    // Se estiver vazio por algum motivo, popula com as categorias essenciais automaticamente
    if (rows.isEmpty) {
      await _seedDefaultCategories();
      rows = await db.query('categories', orderBy: 'name ASC');
    }

    return rows.map((row) {
      return CategoryModel(
        id: row['id'] as String,
        name: row['name'] as String,
        type: (row['type'] as String).toLowerCase(),
        color: (row['color'] as String?) ?? '#38BDF8',
      );
    }).toList();
  }

  Future<void> _seedDefaultCategories() async {
    final db = await _dbHelper.database;
    final defaultCategories = [
      {
        'id': 'cat_alim',
        'name': 'Alimentação',
        'type': 'expense',
        'color': '#EF4444',
        'icon': 'Utensils'
      },
      {
        'id': 'cat_transp',
        'name': 'Transporte',
        'type': 'expense',
        'color': '#3B82F6',
        'icon': 'Car'
      },
      {
        'id': 'cat_moradia',
        'name': 'Moradia',
        'type': 'expense',
        'color': '#10B981',
        'icon': 'Home'
      },
      {
        'id': 'cat_lazer',
        'name': 'Lazer',
        'type': 'expense',
        'color': '#F59E0B',
        'icon': 'Gamepad'
      },
      {
        'id': 'cat_saude',
        'name': 'Saúde',
        'type': 'expense',
        'color': '#F43F5E',
        'icon': 'HeartPulse'
      },
      {
        'id': 'cat_educacao',
        'name': 'Educação',
        'type': 'expense',
        'color': '#06B6D4',
        'icon': 'GraduationCap'
      },
      {
        'id': 'cat_outros',
        'name': 'Outros',
        'type': 'expense',
        'color': '#A8A29E',
        'icon': 'Tag'
      },
      {
        'id': 'cat_salario',
        'name': 'Salário',
        'type': 'income',
        'color': '#10B981',
        'icon': 'Wallet'
      },
      {
        'id': 'cat_invest',
        'name': 'Investimentos',
        'type': 'income',
        'color': '#06B6D4',
        'icon': 'TrendingUp'
      },
      {
        'id': 'cat_rendim',
        'name': 'Rendimentos',
        'type': 'income',
        'color': '#14B8A6',
        'icon': 'DollarSign'
      },
      {
        'id': 'cat_outras_rec',
        'name': 'Outras Receitas',
        'type': 'income',
        'color': '#3B82F6',
        'icon': 'PlusCircle'
      },
    ];

    for (final c in defaultCategories) {
      await db.insert(
        'categories',
        {
          'id': c['id'],
          'name': c['name'],
          'type': c['type'],
          'color': c['color'],
          'icon': c['icon'],
          'user_id': 'local_user_default',
        },
        conflictAlgorithm: null,
      );
    }
  }

  Future<bool> createCategory({
    required String name,
    required String type,
    String color = '#38BDF8',
  }) async {
    final db = await _dbHelper.database;
    final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('categories', {
      'id': id,
      'name': name.trim(),
      'type': type.toLowerCase(),
      'color': color,
      'user_id': 'local_user_default',
    });

    return true;
  }

  Future<bool> updateCategory(
    String id, {
    required String name,
    required String type,
    String color = '#38BDF8',
  }) async {
    final db = await _dbHelper.database;

    await db.update(
      'categories',
      {
        'name': name.trim(),
        'type': type.toLowerCase(),
        'color': color,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return true;
  }

  Future<bool> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}
