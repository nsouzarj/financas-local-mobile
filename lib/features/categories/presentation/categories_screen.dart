import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../data/category_service.dart';
import '../models/category_model.dart';
import 'category_form_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  final bool isEmbedded;

  const CategoriesScreen({super.key, this.isEmbedded = false});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CategoryService _categoryService = CategoryService();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _categoryService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar categorias.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openCategoryForm([CategoryModel? category]) async {
    final currentTabType = _tabController.index == 0 ? 'expense' : 'income';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoryFormDialog(
        category: category,
        initialType: currentTabType,
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  Future<void> _confirmDelete(CategoryModel category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Excluir Categoria?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja remover a categoria "${category.name}"?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _categoryService.deleteCategory(category.id);
      if (success) {
        _loadCategories();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir a categoria.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkinController.instance,
      builder: (context, _) {
        final expenseCategories = _categories.where((c) => c.isExpense || c.isBoth).toList();
        final incomeCategories = _categories.where((c) => c.isIncome || c.isBoth).toList();

        final content = _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadCategories, child: const Text('Tentar novamente')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Barra de tipo e botão nova categoria se for embutido
                      Container(
                        color: AppTheme.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: AppTheme.primary,
                                labelColor: AppTheme.primary,
                                unselectedLabelColor: AppTheme.textSecondary,
                                tabs: [
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.arrow_upward, size: 15, color: AppTheme.expense),
                                        const SizedBox(width: 4),
                                        Text('Despesas (${expenseCategories.length})'),
                                      ],
                                    ),
                                  ),
                                  Tab(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.arrow_downward, size: 15, color: AppTheme.income),
                                        const SizedBox(width: 4),
                                        Text('Receitas (${incomeCategories.length})'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.isEmbedded) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Nova', style: TextStyle(fontSize: 12)),
                                onPressed: () => _openCategoryForm(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildCategoryList(expenseCategories, 'Nenhuma categoria de despesa cadastrada.'),
                            _buildCategoryList(incomeCategories, 'Nenhuma categoria de receita cadastrada.'),
                          ],
                        ),
                      ),
                    ],
                  );

        if (widget.isEmbedded) {
          return content;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categorias'),
            actions: [
              IconButton(
                icon: Icon(Icons.add, color: AppTheme.primary),
                tooltip: 'Nova Categoria',
                onPressed: () => _openCategoryForm(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_upward, size: 16, color: AppTheme.expense),
                      const SizedBox(width: 6),
                      Text('Despesas (${expenseCategories.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward, size: 16, color: AppTheme.income),
                      const SizedBox(width: 6),
                      Text('Receitas (${incomeCategories.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadCategories, child: const Text('Tentar novamente')),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryList(expenseCategories, 'Nenhuma categoria de despesa cadastrada.'),
                        _buildCategoryList(incomeCategories, 'Nenhuma categoria de receita cadastrada.'),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildCategoryList(List<CategoryModel> list, String emptyMessage) {
    final isExpense = _tabController.index == 0;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_outlined, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(emptyMessage, style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openCategoryForm(),
                icon: const Icon(Icons.add),
                label: Text(isExpense ? 'Criar Categoria de Despesa' : 'Criar Categoria de Receita'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: _loadCategories,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.6), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: AppTheme.primary.withOpacity(0.08),
                ),
                icon: Icon(Icons.add_circle, color: AppTheme.primary, size: 20),
                label: Text(
                  isExpense ? '+ Cadastrar Categoria de Despesa' : '+ Cadastrar Categoria de Receita',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onPressed: () => _openCategoryForm(),
              ),
            );
          }

          final cat = list[index - 1];
          int colorInt;
          try {
            colorInt = int.parse(cat.color.replaceFirst('#', '0xFF'));
          } catch (_) {
            colorInt = 0xFF38BDF8;
          }
          final catColor = Color(colorInt);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openCategoryForm(cat),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 18),
                      tooltip: 'Editar Categoria',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _openCategoryForm(cat),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                      color: AppTheme.surfaceLight,
                      onSelected: (val) {
                        if (val == 'edit') _openCategoryForm(cat);
                        if (val == 'delete') _confirmDelete(cat);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: AppTheme.expense))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

