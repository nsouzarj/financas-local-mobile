import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/controllers/value_visibility_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/transaction_service.dart';
import '../models/transaction_model.dart';
import 'new_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<TransactionModel> _allTransactions = [];
  bool _isLoading = true;
  String? _error;

  // Filtros
  DateTime _selectedDate = DateTime.now();
  bool _isAllMonths = false; // Se true, busca histórico completo
  String _selectedType = 'all'; // 'all', 'expense', 'income'

  @override
  void initState() {
    super.initState();
    DataRefreshController.instance.addListener(_onDataChanged);
    _loadTransactions();
  }

  @override
  void dispose() {
    DataRefreshController.instance.removeListener(_onDataChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadTransactions();
  }

  // Normalizador para busca sem diferenciar acentos ou maiúsculas
  String _normalize(String text) {
    const withAccents = 'áàãâäéèêëíìîïóòõôöúùûüçñÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑ';
    const withoutAccents = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
    var output = text;
    for (int i = 0; i < withAccents.length; i++) {
      output = output.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return output.toLowerCase();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? startDate;
      String? endDate;

      if (!_isAllMonths) {
        final year = _selectedDate.year;
        final month = _selectedDate.month;
        final firstDay = DateTime(year, month, 1);
        final lastDay = DateTime(year, month + 1, 0);

        startDate = DateFormat('yyyy-MM-dd').format(firstDay);
        endDate = DateFormat('yyyy-MM-dd').format(lastDay);
      }

      final list = await _transactionService.getTransactions(
        type: _selectedType,
        startDate: startDate,
        endDate: endDate,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _allTransactions = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar lançamentos.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    // Atualização instantânea em tela
    setState(() {});
    // E recarrega na API se necessário após 400ms
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadTransactions();
    });
  }

  void _previousMonth() {
    setState(() {
      _isAllMonths = false;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
    _loadTransactions();
  }

  void _nextMonth() {
    setState(() {
      _isAllMonths = false;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
    _loadTransactions();
  }

  void _setTodayMonth() {
    setState(() {
      _isAllMonths = false;
      _selectedDate = DateTime.now();
    });
    _loadTransactions();
  }

  void _toggleAllMonths() {
    setState(() {
      _isAllMonths = !_isAllMonths;
    });
    _loadTransactions();
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Excluir Lançamento?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja remover "${tx.description}" (${CurrencyFormatter.format(tx.amount)})? O saldo da conta será recalculado automaticamente.',
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
      final success = await _transactionService.deleteTransaction(tx.id);
      if (success) {
        _loadTransactions();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível excluir o lançamento.')),
        );
      }
    }
  }

  Future<void> _openEditTransaction(TransactionModel tx) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewTransactionScreen(transaction: tx)),
    );
    if (updated == true) _loadTransactions();
  }

  // Filtro inteligente local (instantâneo)
  List<TransactionModel> get _filteredTransactions {
    final query = _normalize(_searchController.text.trim());
    return _allTransactions.where((tx) {
      // Filtro de tipo
      if (_selectedType == 'income' && !tx.isIncome) return false;
      if (_selectedType == 'expense' && !tx.isExpense) return false;

      // Filtro de busca textual em múltiplos campos
      if (query.isNotEmpty) {
        final desc = _normalize(tx.description);
        final cat = _normalize(tx.categoryName ?? '');
        final acc = _normalize(tx.accountName ?? '');
        if (!desc.contains(query) && !cat.contains(query) && !acc.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ValueVisibilityController.instance,
        SkinController.instance,
      ]),
      builder: (context, _) {
        final displayList = _filteredTransactions;

        // Totais calculados estritamente sobre a lista exibida (filtrada pelo mês/busca)
        final totalIncome = displayList
            .where((t) => t.isIncome)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        final totalExpense = displayList
            .where((t) => t.isExpense)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        final netBalance = totalIncome - totalExpense;

        final monthLabel = CurrencyFormatter.formatMonthYear(_selectedDate);
        final formattedMonthName = monthLabel;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Extrato & Lançamentos'),
            actions: [
              const EyeVisibilityButton(),
              IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color: _isAllMonths ? AppTheme.primary : AppTheme.textSecondary,
                ),
                tooltip: _isAllMonths ? 'Voltar para visão mensal' : 'Ver todo o histórico',
                onPressed: _toggleAllMonths,
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color(0xFF0F172A),
        child: const Icon(Icons.add, size: 24),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NewTransactionScreen()),
          );
          if (created == true) _loadTransactions();
        },
      ),
      body: Column(
        children: [
          // 1. Barra de Navegação do Mês
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isAllMonths)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.all_inclusive, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Todo o Histórico',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _setTodayMonth,
                          child: Text('Ver este mês', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        ),
                      ],
                    ),
                  )
                else ...[
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                    onPressed: _previousMonth,
                  ),
                  GestureDetector(
                    onTap: _setTodayMonth,
                    child: Row(
                      children: [
                        Text(
                          formattedMonthName,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 20),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: AppTheme.textPrimary),
                    onPressed: _nextMonth,
                  ),
                ],
              ],
            ),
          ),

          // 2. Campo de Busca Instantâneo e Filtros
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: AppTheme.background,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por descrição, conta ou categoria...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppTheme.textMuted, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),

                // Chips de Tipo (Todos / Despesas / Receitas)
                Row(
                  children: [
                    _buildFilterChip('all', 'Todos (${_allTransactions.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('expense', 'Despesas', AppTheme.expense),
                    const SizedBox(width: 8),
                    _buildFilterChip('income', 'Receitas', AppTheme.income),
                  ],
                ),
              ],
            ),
          ),

          // 3. Card de Totais do Período Selecionado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entradas (+)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.formatOrHide(totalIncome),
                          style: TextStyle(color: AppTheme.income, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.5)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saídas (-)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.formatOrHide(totalExpense),
                            style: TextStyle(color: AppTheme.expense, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.5)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Balanço', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.formatOrHide(netBalance),
                          style: TextStyle(
                            color: netBalance >= 0 ? AppTheme.primary : AppTheme.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 4. Lista dos Lançamentos Formatada
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadTransactions, child: const Text('Tentar novamente')),
                          ],
                        ),
                      )
                    : displayList.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'Nenhum lançamento encontrado para "${_searchController.text}".'
                                        : 'Nenhum lançamento registrado neste período.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                            onRefresh: _loadTransactions,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                              itemCount: displayList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildPremiumTransactionCard(displayList[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, [Color? activeColor]) {
    final isSelected = _selectedType == value;
    final color = activeColor ?? AppTheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = value);
        _loadTransactions();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // Card de Lançamento Redesenhado: Elegante, Espaçoso, Sem Overflow e com Ícones 100% Dentro do Card
  Widget _buildPremiumTransactionCard(TransactionModel tx) {
    final isIncome = tx.isIncome;
    final amountColor = isIncome ? AppTheme.income : AppTheme.expense;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditTransaction(tx),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: Ícone + Descrição/Data + Valor
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone de Tipo de Transação
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: amountColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: amountColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Descrição e Data (com proteção contra overflow)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatDate(tx.date),
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Valor Formatado
                  Text(
                    '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatOrHide(tx.amount)}',
                    style: TextStyle(
                      color: amountColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Linha divisória sutil
              Divider(color: AppTheme.border.withOpacity(0.35), height: 1),
              const SizedBox(height: 8),

              // Linha 2: Badges Flexíveis e Botões de Ação Totalmente Contidos Dentro do Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badges flexíveis que quebram de linha se a tela for pequena
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Badge Categoria
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_outline, size: 11, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 90),
                                child: Text(
                                  tx.categoryName ?? 'Sem categoria',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badge Conta Bancária
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.border.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.account_balance_outlined, size: 11, color: AppTheme.textSecondary),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 85),
                                child: Text(
                                  tx.accountName ?? 'Conta',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Badge Status (Pago / Pendente)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: tx.isPaid
                                ? AppTheme.income.withOpacity(0.12)
                                : AppTheme.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: tx.isPaid
                                  ? AppTheme.income.withOpacity(0.3)
                                  : AppTheme.warning.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tx.isPaid ? Icons.check_circle_outline : Icons.access_time,
                                size: 11,
                                color: tx.isPaid ? AppTheme.income : AppTheme.warning,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tx.isPaid ? 'Pago' : 'Pendente',
                                style: TextStyle(
                                  color: tx.isPaid ? AppTheme.income : AppTheme.warning,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Ações (Editar & Excluir) dentro de botões compactos e bem contidos
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão de Editar
                      Material(
                        color: AppTheme.surfaceLight.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _openEditTransaction(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Botão de Excluir
                      Material(
                        color: AppTheme.expense.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _confirmDelete(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: AppTheme.expense,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
