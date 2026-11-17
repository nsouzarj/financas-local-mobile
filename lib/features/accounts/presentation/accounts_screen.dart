import 'package:flutter/material.dart';
import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/controllers/value_visibility_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../categories/models/category_model.dart';
import '../../categories/presentation/categories_screen.dart';
import '../../categories/presentation/category_form_dialog.dart';
import '../data/account_service.dart';
import '../models/account_model.dart';
import 'account_form_dialog.dart';

class AccountsScreen extends StatefulWidget {
  final int initialTab;

  const AccountsScreen({super.key, this.initialTab = 0});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AccountService _accountService = AccountService();
  List<AccountModel> _accounts = [];
  bool _isLoading = true;
  String? _error;
  Key _categoriesKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    DataRefreshController.instance.addListener(_onDataChanged);
    _loadAccounts();
  }

  @override
  void dispose() {
    DataRefreshController.instance.removeListener(_onDataChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final accounts = await _accountService.getAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar contas.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openAccountForm([AccountModel? account]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AccountFormDialog(account: account),
    );

    if (result == true) {
      _loadAccounts();
    }
  }

  Future<void> _openCategoryForm([CategoryModel? category]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoryFormDialog(category: category),
    );

    if (result == true) {
      setState(() {
        _categoriesKey = UniqueKey();
      });
    }
  }

  Future<void> _confirmDelete(AccountModel account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Excluir Conta?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja realmente remover a conta "${account.name}"? As transações associadas podem ser afetadas.',
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
      final success = await _accountService.deleteAccount(account.id);
      if (success) {
        _loadAccounts();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir a conta.')),
        );
      }
    }
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppTheme.primary;
    try {
      final hex = hexString.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ValueVisibilityController.instance,
        SkinController.instance,
      ]),
      builder: (context, _) {
        final totalBalance = _accounts.fold<double>(
          0.0,
          (sum, acc) => sum + (acc.isCreditCard ? -acc.balance : acc.balance),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _tabController.index == 0 ? 'Contas & Cartões' : 'Categorias',
            ),
            actions: [
              const EyeVisibilityButton(),
              if (_tabController.index == 0)
                IconButton(
                  icon: Icon(Icons.add_card, color: AppTheme.primary),
                  tooltip: 'Adicionar Conta',
                  onPressed: () => _openAccountForm(),
                )
              else
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 26),
                  tooltip: 'Adicionar Categoria',
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
                      const Icon(Icons.account_balance_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Contas (${_accounts.length})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Categorias'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppTheme.primary,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 4,
            icon: Icon(
              _tabController.index == 0 ? Icons.add_card : Icons.add,
              size: 20,
            ),
            label: Text(
              _tabController.index == 0 ? 'Nova Conta' : 'Nova Categoria',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: () {
              if (_tabController.index == 0) {
                _openAccountForm();
              } else {
                _openCategoryForm();
              }
            },
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAccountsView(totalBalance),
              CategoriesScreen(key: _categoriesKey, isEmbedded: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountsView(double totalBalance) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadAccounts,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: _loadAccounts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cartão de Saldo Consolidado
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Geral em Contas',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatOrHide(totalBalance),
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seção de Contas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Minhas Contas e Cartões',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_accounts.length} cadastrada(s)',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_accounts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.credit_card_off_outlined,
                      size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhuma conta cadastrada.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _openAccountForm(),
                    child: Text('Cadastrar Conta',
                        style: TextStyle(color: AppTheme.primary)),
                  ),
                ],
              ),
            )
          else
            ..._accounts.map((acc) {
              final accColor = _parseColor(acc.color);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      acc.isCreditCard
                          ? Icons.credit_card
                          : Icons.account_balance_wallet,
                      color: accColor,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    acc.name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    acc.typeLabel,
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.formatOrHide(
                              acc.isCreditCard ? -acc.balance : acc.balance,
                            ),
                            style: TextStyle(
                              color: acc.isCreditCard
                                  ? AppTheme.expense
                                  : (acc.balance >= 0
                                      ? AppTheme.textPrimary
                                      : AppTheme.expense),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (acc.isCreditCard && (acc.creditLimit ?? 0) > 0)
                            Text(
                              'Limite: ${CurrencyFormatter.formatOrHide(acc.creditLimit ?? 0)}',
                              style: TextStyle(
                                  color: AppTheme.textMuted, fontSize: 10),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: AppTheme.textSecondary, size: 20),
                        color: AppTheme.surface,
                        onSelected: (val) {
                          if (val == 'edit') {
                            _openAccountForm(acc);
                          } else if (val == 'delete') {
                            _confirmDelete(acc);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: AppTheme.expense),
                                const SizedBox(width: 8),
                                Text('Excluir',
                                    style:
                                        TextStyle(color: AppTheme.expense)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
