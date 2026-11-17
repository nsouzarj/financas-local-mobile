import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../categories/presentation/category_form_dialog.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../transactions/models/transaction_model.dart';
import '../data/planning_service.dart';

class PlanningFormDialog extends StatefulWidget {
  final TransactionModel? plannedTx;

  const PlanningFormDialog({super.key, this.plannedTx});

  @override
  State<PlanningFormDialog> createState() => _PlanningFormDialogState();
}

class _PlanningFormDialogState extends State<PlanningFormDialog> {
  final _planningService = PlanningService();
  final _dashboardService = DashboardService();
  final _formKey = GlobalKey<FormState>();

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController(text: '0,00');

  String _type = 'expense';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _reminderDays = 7;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedAccountId;
  String? _selectedCategoryId;

  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<int> _reminderOptions = [0, 1, 3, 5, 7, 10, 15, 30];

  String _formatReminderText(int days) {
    if (days == 0) return 'No dia do vencimento';
    if (days == 1) return '1 dia antes';
    return '$days dias antes';
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
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

        if (widget.plannedTx != null) {
          final tx = widget.plannedTx!;
          _descriptionController.text = tx.description;
          _amountController.text = tx.amount.toStringAsFixed(2).replaceAll('.', ',');
          _type = tx.type;
          _dueDate = tx.dueDate ?? tx.date;
          _reminderDays = tx.reminderDays ?? 7;
          _selectedAccountId = tx.accountId ?? (_accounts.isNotEmpty ? _accounts.first['id']?.toString() : null);
          _selectedCategoryId = tx.categoryId ?? (_categories.isNotEmpty ? _categories.first['id']?.toString() : null);
        } else {
          if (_accounts.isNotEmpty) _selectedAccountId = _accounts.first['id']?.toString();
          _filterCategory();
        }

        _isLoadingInitial = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingInitial = false;
        _errorMessage = 'Não foi possível carregar contas e categorias.';
      });
    }
  }

  void _filterCategory() {
    final valid = _categories.where((c) {
      final cType = c['type']?.toString().toLowerCase();
      return cType == _type || cType == 'both' || cType == null;
    }).toList();

    if (valid.isNotEmpty) {
      _selectedCategoryId = valid.first['id']?.toString();
    } else {
      _selectedCategoryId = null;
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primary,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
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
      if (_categories.isNotEmpty) {
        setState(() {
          _selectedCategoryId = _categories.last['id']?.toString();
        });
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final description = _descriptionController.text.trim();
    final amount = CurrencyFormatter.parseCurrencyToNumber(_amountController.text);

    if (description.isEmpty || amount <= 0) {
      setState(() => _errorMessage = 'Informe uma descrição e valor válido.');
      return;
    }

    if (_selectedAccountId == null || _selectedCategoryId == null) {
      setState(() => _errorMessage = 'Selecione uma conta e categoria.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    bool success;
    if (widget.plannedTx == null) {
      success = await _planningService.createPlannedTransaction(
        description: description,
        amount: amount,
        type: _type,
        dueDate: _dueDate,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        reminderDays: _reminderDays,
      );
    } else {
      success = await _planningService.updatePlannedTransaction(
        id: widget.plannedTx!.id,
        description: description,
        amount: amount,
        type: _type,
        dueDate: _dueDate,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId!,
        reminderDays: _reminderDays,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(() => _errorMessage = 'Falha ao salvar a previsão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.plannedTx != null;
    final activeColor = _type == 'income' ? AppTheme.income : AppTheme.expense;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480),
        child: _isLoadingInitial
            ? SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.alarm_add_rounded, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isEditing ? 'Editar Previsão' : 'Nova Previsão',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tipo (Despesa / Receita)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _type = 'expense';
                                    _filterCategory();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: _type == 'expense' ? AppTheme.expense : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Despesa Futura',
                                      style: TextStyle(
                                        color: _type == 'expense' ? Colors.white : AppTheme.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
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
                                    _filterCategory();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: _type == 'income' ? AppTheme.income : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Receita Futura',
                                      style: TextStyle(
                                        color: _type == 'income' ? Colors.white : AppTheme.textMuted,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.expense.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expense.withOpacity(0.4)),
                          ),
                          child: Text(_errorMessage!, style: TextStyle(color: AppTheme.expense, fontSize: 12)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Valor com máscara em tempo real R$ 200,31
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: activeColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Valor Previsto',
                          prefixText: 'R\$ ',
                          prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: activeColor),
                          hintText: '0,00',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Descrição
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição da Previsão',
                          hintText: 'Ex: Conta de Luz, Fatura Cartão, IPVA',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
                      ),
                      const SizedBox(height: 14),

                      // Data de Vencimento
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data de Vencimento',
                            suffixIcon: Icon(Icons.calendar_today, color: AppTheme.primary, size: 20),
                          ),
                          child: Text(
                            CurrencyFormatter.formatDate(_dueDate),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Alarme / Lembrete de Antecedência
                      DropdownButtonFormField<int>(
                        value: _reminderDays,
                        dropdownColor: AppTheme.surface,
                        decoration: InputDecoration(
                          labelText: 'Alarme de Antecedência',
                          prefixIcon: Icon(Icons.notifications_active_outlined, color: AppTheme.primary, size: 20),
                        ),
                        items: _reminderOptions.map((days) {
                          return DropdownMenuItem<int>(
                            value: days,
                            child: Text(_formatReminderText(days)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _reminderDays = val ?? 7),
                      ),
                      const SizedBox(height: 14),

                      // Conta Prevista
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        dropdownColor: AppTheme.surface,
                        decoration: const InputDecoration(labelText: 'Conta Bancária Prevista'),
                        items: _accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc['id']?.toString(),
                            child: Text(acc['name'] ?? 'Conta'),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAccountId = val),
                      ),
                      const SizedBox(height: 14),

                      // Categoria com atalho para cadastrar nova
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedCategoryId,
                              dropdownColor: AppTheme.surface,
                              decoration: const InputDecoration(labelText: 'Categoria'),
                              items: _categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c['id']?.toString(),
                                  child: Text(c['name'] ?? 'Categoria'),
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
                      const SizedBox(height: 22),

                      // Botão Salvar
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isSaving ? null : _handleSave,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                )
                              : Text(
                                  isEditing ? 'Atualizar Previsão' : 'Salvar Previsão',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

