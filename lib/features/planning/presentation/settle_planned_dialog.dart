import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/data/dashboard_service.dart';
import '../../transactions/models/transaction_model.dart';
import '../data/planning_service.dart';

class SettlePlannedDialog extends StatefulWidget {
  final TransactionModel plannedTx;

  const SettlePlannedDialog({
    super.key,
    required this.plannedTx,
  });

  static Future<bool?> show(BuildContext context, TransactionModel plannedTx) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SettlePlannedDialog(plannedTx: plannedTx),
    );
  }

  @override
  State<SettlePlannedDialog> createState() => _SettlePlannedDialogState();
}

class _SettlePlannedDialogState extends State<SettlePlannedDialog> {
  final _planningService = PlanningService();
  final _dashboardService = DashboardService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedCategoryId;

  // Opções para valor parcial: 'next_month', 'keep_current', 'none'
  String _remainderAction = 'next_month';

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingInitial = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final tx = widget.plannedTx;
    _descriptionController = TextEditingController(text: tx.description);
    _amountController = TextEditingController(
      text: tx.amount.toStringAsFixed(2).replaceAll('.', ','),
    );
    _loadOptions();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
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

        final tx = widget.plannedTx;
        _selectedAccountId = tx.accountId ??
            (_accounts.isNotEmpty ? _accounts.first['id']?.toString() : null);
        _selectedCategoryId = tx.categoryId ??
            (_categories.isNotEmpty ? _categories.first['id']?.toString() : null);

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

  double get _currentAmount =>
      CurrencyFormatter.parseCurrencyToNumber(_amountController.text);

  double get _remainder => widget.plannedTx.amount - _currentAmount;

  bool get _isPartial => _remainder > 0.009;

  Future<void> _selectPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.income,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final paidAmount = _currentAmount;
    if (paidAmount <= 0) {
      setState(() => _errorMessage = 'O valor a pagar deve ser maior que zero.');
      return;
    }

    if (_selectedAccountId == null || _selectedAccountId!.isEmpty) {
      setState(() => _errorMessage = 'Selecione a conta para débito/crédito.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tx = widget.plannedTx;
      final originalDue = tx.dueDate ?? tx.date;

      final success = await _planningService.settlePlannedTransaction(
        plannedId: tx.id,
        paidAmount: paidAmount,
        paymentDate: _paymentDate,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId ?? '',
        description: _descriptionController.text.trim(),
        type: tx.type,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        originalAmount: tx.amount,
        originalDueDate: originalDue,
        remainderAction: _isPartial ? _remainderAction : 'none',
      );

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Erro ao registrar baixa no banco de dados.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Falha ao processar baixa: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.plannedTx;
    final isIncome = tx.isIncome;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    final originalDueDate = tx.dueDate ?? tx.date;

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _isLoadingInitial
            ? Container(
                height: 200,
                alignment: Alignment.center,
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Baixar Conta do Planejamento',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Previsto: ${CurrencyFormatter.format(tx.amount)} • Venc: ${CurrencyFormatter.formatDate(originalDueDate)}',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: AppTheme.border.withOpacity(0.5), height: 1),
                      const SizedBox(height: 16),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.expense.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.expense.withOpacity(0.3)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: AppTheme.expense, fontSize: 12),
                          ),
                        ),

                      // Campo: Valor Pago Agora
                      Text(
                        'Valor Efetivo da Baixa (R\$)',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Text(
                              'R\$',
                              style: TextStyle(
                                color: color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          hintText: '0,00',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: color, width: 2),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Informe o valor.';
                          final numVal = CurrencyFormatter.parseCurrencyToNumber(v);
                          if (numVal <= 0) return 'O valor deve ser maior que zero.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Bloco Especial: Pagamento Parcial Detectado
                      if (_isPartial)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppTheme.warning, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pagamento Parcial Detectado',
                                    style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Diferença restante:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(_remainder),
                                    style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'O que deseja fazer com a diferença?',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Opção 1: Agendar restante pro próximo mês
                              InkWell(
                                onTap: () => setState(() => _remainderAction = 'next_month'),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'next_month',
                                        groupValue: _remainderAction,
                                        activeColor: AppTheme.warning,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _remainderAction = val);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Agendar restante (${CurrencyFormatter.format(_remainder)}) para o próximo mês',
                                          style: TextStyle(
                                            color: _remainderAction == 'next_month'
                                                ? AppTheme.textPrimary
                                                : AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: _remainderAction == 'next_month'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Opção 2: Manter restante em aberto neste mês
                              InkWell(
                                onTap: () => setState(() => _remainderAction = 'keep_current'),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'keep_current',
                                        groupValue: _remainderAction,
                                        activeColor: AppTheme.warning,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _remainderAction = val);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Manter restante em aberto no planejamento deste mês',
                                          style: TextStyle(
                                            color: _remainderAction == 'keep_current'
                                                ? AppTheme.textPrimary
                                                : AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: _remainderAction == 'keep_current'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Opção 3: Quitar sem restante (desconto/quitação)
                              InkWell(
                                onTap: () => setState(() => _remainderAction = 'none'),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'none',
                                        groupValue: _remainderAction,
                                        activeColor: AppTheme.warning,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) {
                                          if (val != null) setState(() => _remainderAction = val);
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Quitar integralmente (desconsiderar diferença)',
                                          style: TextStyle(
                                            color: _remainderAction == 'none'
                                                ? AppTheme.textPrimary
                                                : AppTheme.textSecondary,
                                            fontSize: 12,
                                            fontWeight: _remainderAction == 'none'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Campo: Data do Pagamento
                      Text(
                        'Data do Pagamento / Efetivação',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _selectPaymentDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, color: AppTheme.income, size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    CurrencyFormatter.formatDate(_paymentDate),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Alterar data',
                                style: TextStyle(color: AppTheme.income, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Campo: Conta Bancária / Carteira
                      Text(
                        'Conta de Pagamento / Saída',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        dropdownColor: AppTheme.surface,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 18),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        items: _accounts.map((acc) {
                          final accName = acc['name']?.toString() ?? 'Conta';
                          final balance = (acc['balance'] as num?)?.toDouble() ?? 0.0;
                          return DropdownMenuItem<String>(
                            value: acc['id']?.toString(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(accName, overflow: TextOverflow.ellipsis),
                                const SizedBox(width: 8),
                                Text(
                                  '(${CurrencyFormatter.format(balance)})',
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAccountId = val),
                        validator: (v) => (v == null || v.isEmpty) ? 'Selecione uma conta.' : null,
                      ),
                      const SizedBox(height: 12),

                      // Campo: Categoria
                      Text(
                        'Categoria',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        dropdownColor: AppTheme.surface,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.category_rounded, color: AppTheme.textSecondary, size: 18),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat['id']?.toString(),
                            child: Text(cat['name']?.toString() ?? 'Categoria', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCategoryId = val),
                      ),
                      const SizedBox(height: 12),

                      // Campo: Descrição
                      Text(
                        'Descrição do Lançamento',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : null,
                      ),
                      const SizedBox(height: 12),

                      // Campo: Observações (Opcional)
                      Text(
                        'Observações / Detalhes (Opcional)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Ex: Parcela paga via PIX...',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Botões de Ação
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSaving ? null : () => Navigator.pop(context, false),
                              child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.income,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: _isSaving ? null : _handleConfirm,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.check_circle_rounded, size: 18),
                                        SizedBox(width: 6),
                                        Text(
                                          'Confirmar Baixa',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

