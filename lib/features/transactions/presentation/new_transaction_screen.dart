import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../categories/presentation/category_form_dialog.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../data/transaction_service.dart';
import '../models/transaction_model.dart';

class NewTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;

  const NewTransactionScreen({super.key, this.transaction});

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final _dashboardService = DashboardService();
  final _transactionService = TransactionService();
  final _amountController = TextEditingController(text: '0,00');
  final _descriptionController = TextEditingController();

  String _type = 'expense'; // 'expense' ou 'income'
  String _status = 'paid';  // 'paid', 'pending' ou 'planned'
  int _reminderDays = 7;
  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedAccountId;
  String? _selectedCategoryId;

  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _descriptionController.text = tx.description;
      _amountController.text = tx.amount.toStringAsFixed(2).replaceAll('.', ',');
      _type = tx.type;
      _status = tx.status;
      _selectedDate = tx.date;
      _reminderDays = tx.reminderDays ?? 7;
      _selectedAccountId = tx.accountId;
      _selectedCategoryId = tx.categoryId;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final results = await Future.wait([
        _dashboardService.fetchAccounts(),
        _dashboardService.fetchCategories(),
      ]);

      if (!mounted) return;

      setState(() {
        _accounts = results[0];
        _categories = results[1];

        if (widget.transaction != null) {
          final tx = widget.transaction!;
          _selectedAccountId = tx.accountId ?? (_accounts.isNotEmpty ? _accounts.first['id']?.toString() : null);
          _selectedCategoryId = tx.categoryId ?? (_categories.isNotEmpty ? _categories.first['id']?.toString() : null);
        } else {
          if (_accounts.isNotEmpty) _selectedAccountId = _accounts.first['id']?.toString();
          _filterAndSelectCategory();
        }

        _isLoadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingInitial = false;
        _errorMessage = 'Não foi possível carregar as contas e categorias.';
      });
    }
  }

  void _filterAndSelectCategory() {
    final validCategories = _categories.where((c) {
      final cType = c['type']?.toString().toLowerCase();
      return cType == _type || cType == 'both' || cType == null;
    }).toList();

    if (validCategories.isNotEmpty) {
      _selectedCategoryId = validCategories.first['id']?.toString();
    } else {
      _selectedCategoryId = null;
    }
  }

  Future<void> _openQuickCategoryForm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoryFormDialog(
        initialType: _type,
      ),
    );

    if (result == true) {
      await _loadOptions();
      final updatedFiltered = _categories.where((c) {
        final cType = c['type']?.toString().toLowerCase();
        return cType == _type || cType == 'both' || cType == null;
      }).toList();
      if (updatedFiltered.isNotEmpty) {
        setState(() {
          _selectedCategoryId = updatedFiltered.last['id']?.toString();
        });
      }
    }
  }

  Future<void> _handleSave() async {
    final description = _descriptionController.text.trim();
    final amount = CurrencyFormatter.parseCurrencyToNumber(_amountController.text);

    if (description.isEmpty || amount <= 0) {
      setState(() => _errorMessage = 'Informe uma descrição e um valor válido maior que zero.');
      return;
    }

    if (_selectedAccountId == null || _selectedCategoryId == null) {
      setState(() => _errorMessage = 'Selecione uma conta e uma categoria.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      bool success;
      if (widget.transaction != null) {
        success = await _transactionService.updateTransaction(
          id: widget.transaction!.id,
          description: description,
          amount: amount,
          type: _type,
          date: _selectedDate,
          status: _status,
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId!,
          reminderDays: _status == 'planned' ? _reminderDays : null,
          dueDate: _status == 'planned' ? _selectedDate : null,
        );
      } else {
        success = await _dashboardService.createTransaction(
          accountId: _selectedAccountId!,
          categoryId: _selectedCategoryId!,
          description: description,
          amount: amount,
          type: _type,
          date: _selectedDate,
          status: _status,
          reminderDays: _status == 'planned' ? _reminderDays : null,
          dueDate: _status == 'planned' ? _selectedDate : null,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() => _errorMessage = 'Falha ao salvar lançamento.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Erro ao conectar ao servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.transaction != null;
    final isIncome = _type == 'income';
    final activeColor = isIncome ? AppTheme.income : AppTheme.expense;

    final filteredCategories = _categories.where((c) {
      final cType = c['type']?.toString().toLowerCase();
      return cType == _type || cType == 'both' || cType == null;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Editar Lançamento'
              : (isIncome ? 'Nova Receita' : 'Nova Despesa'),
        ),
      ),
      body: _isLoadingInitial
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Seletor Tipo: Despesa / Receita
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = 'expense';
                                _filterAndSelectCategory();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == 'expense' ? AppTheme.expense : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Despesa',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _type == 'expense' ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _type = 'income';
                                _filterAndSelectCategory();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _type == 'income' ? AppTheme.income : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Receita',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _type == 'income' ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.expense.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.expense.withOpacity(0.4)),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: AppTheme.expense, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Campo de Valor Formatado dinamicamente no estilo R$ 200,31
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Valor do Lançamento',
                      prefixText: 'R\$ ',
                      prefixStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: activeColor,
                      ),
                      hintText: '0,00',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descrição
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Ex: Almoço, Salário, Supermercado',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conta Bancária
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Conta Bancária'),
                    items: _accounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc['id']?.toString(),
                        child: Text(acc['name'] ?? 'Conta sem nome'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedAccountId = val),
                  ),
                  const SizedBox(height: 16),

                  // Categoria com atalho para cadastrar nova
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          dropdownColor: AppTheme.surface,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          items: filteredCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat['id']?.toString(),
                              child: Text(cat['name'] ?? 'Categoria'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategoryId = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 26),
                        tooltip: 'Cadastrar Nova Categoria',
                        onPressed: _openQuickCategoryForm,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Situação / Status do Lançamento
                  DropdownButtonFormField<String>(
                    value: _status,
                    dropdownColor: AppTheme.surface,
                    decoration: const InputDecoration(labelText: 'Status do Lançamento'),
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('Pago / Efetivado (Debita da Conta)')),
                      DropdownMenuItem(value: 'pending', child: Text('Pendente')),
                      DropdownMenuItem(value: 'planned', child: Text('Previsão Futura (Planejamento)')),
                    ],
                    onChanged: (val) => setState(() => _status = val ?? 'paid'),
                  ),
                  const SizedBox(height: 16),

                  // Se for Previsão Futura, exibe seletor de Alarme de Antecedência
                  if (_status == 'planned') ...[
                    DropdownButtonFormField<int>(
                      value: _reminderDays,
                      dropdownColor: AppTheme.surface,
                      decoration: InputDecoration(
                        labelText: 'Alarme de Antecedência',
                        prefixIcon: Icon(Icons.notifications_active_outlined, color: AppTheme.warning, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('No dia do vencimento')),
                        DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                        DropdownMenuItem(value: 3, child: Text('3 dias antes')),
                        DropdownMenuItem(value: 5, child: Text('5 dias antes')),
                        DropdownMenuItem(value: 7, child: Text('7 dias antes (recomendado)')),
                        DropdownMenuItem(value: 15, child: Text('15 dias antes')),
                        DropdownMenuItem(value: 30, child: Text('30 dias antes')),
                      ],
                      onChanged: (val) => setState(() => _reminderDays = val ?? 7),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Data
                  ListTile(
                    tileColor: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.border),
                    ),
                    leading: Icon(Icons.calendar_today, color: AppTheme.primary, size: 20),
                    title: Text('Data do Lançamento', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    subtitle: Text(
                      CurrencyFormatter.formatDate(_selectedDate),
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    trailing: Icon(Icons.chevron_right, color: AppTheme.textMuted),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (ctx, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: AppTheme.primary,
                                surface: AppTheme.surface,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botão Salvar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(isEditing ? 'Atualizar Lançamento' : 'Salvar Lançamento'),
                  ),
                ],
              ),
            ),
    );
  }
}
