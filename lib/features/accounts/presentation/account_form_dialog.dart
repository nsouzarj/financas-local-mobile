import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/account_service.dart';
import '../models/account_model.dart';

class AccountFormDialog extends StatefulWidget {
  final AccountModel? account;

  const AccountFormDialog({super.key, this.account});

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _closingDayController = TextEditingController();
  final _dueDayController = TextEditingController();
  final _accountService = AccountService();

  String _type = 'Conta Corrente';
  String _selectedColor = '#38BDF8';
  bool _isLoading = false;

  final List<String> _colorOptions = [
    '#38BDF8', // Sky
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#F43F5E', // Rose
    '#8B5CF6', // Indigo
    '#06B6D4', // Cyan
    '#64748B', // Slate
  ];

  static String _mapToDropdownValue(String? rawType) {
    if (rawType == null) return 'Conta Corrente';
    final t = rawType.toLowerCase().trim();
    if (t == 'checking' || t.contains('corrente')) return 'Conta Corrente';
    if (t == 'savings' || t.contains('poup')) return 'Conta Poupança';
    if (t == 'credit' || t == 'credit card' || t == 'credit_card' || t.contains('cart')) return 'Cartão de Crédito';
    if (t == 'investment' || t.contains('invest')) return 'Investimentos';
    if (t == 'cash' || t.contains('dinh') || t.contains('carteira') || t.contains('espécie')) return 'Carteira (Dinheiro)';
    return 'Conta Corrente';
  }

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _nameController.text = widget.account!.name;
      _balanceController.text = (widget.account!.balance).toStringAsFixed(2).replaceAll('.', ',');
      _type = _mapToDropdownValue(widget.account!.type);
      _selectedColor = widget.account!.color;
      if (widget.account!.creditLimit != null) {
        _creditLimitController.text = (widget.account!.creditLimit!).toStringAsFixed(2).replaceAll('.', ',');
      }
      if (widget.account!.closingDay != null) {
        _closingDayController.text = widget.account!.closingDay.toString();
      }
      if (widget.account!.dueDay != null) {
        _dueDayController.text = widget.account!.dueDay.toString();
      }
    } else {
      _balanceController.text = '0,00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _closingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final balance = CurrencyFormatter.parseCurrencyToNumber(_balanceController.text);
    final creditLimit = _creditLimitController.text.isNotEmpty
        ? CurrencyFormatter.parseCurrencyToNumber(_creditLimitController.text)
        : null;
    final closingDay = int.tryParse(_closingDayController.text.trim());
    final dueDay = int.tryParse(_dueDayController.text.trim());

    bool success;
    if (widget.account == null) {
      success = await _accountService.createAccount(
        name: name,
        type: _type,
        balance: balance,
        color: _selectedColor,
        creditLimit: creditLimit,
        closingDay: closingDay,
        dueDay: dueDay,
      );
    } else {
      success = await _accountService.updateAccount(
        widget.account!.id,
        organizationId: widget.account!.organizationId,
        name: name,
        type: _type,
        balance: balance,
        color: _selectedColor,
        creditLimit: creditLimit,
        closingDay: closingDay,
        dueDay: dueDay,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar conta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.account != null;
    final isCredit = _type == 'Cartão de Crédito' || _type == 'Credit Card';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Editar Conta' : 'Nova Conta',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Nome da Conta
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da Conta / Banco'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),

              // Tipo de Conta
              DropdownButtonFormField<String>(
                value: _type,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Tipo de Conta'),
                items: const [
                  DropdownMenuItem(value: 'Conta Corrente', child: Text('Conta Corrente')),
                  DropdownMenuItem(value: 'Conta Poupança', child: Text('Conta Poupança')),
                  DropdownMenuItem(value: 'Cartão de Crédito', child: Text('Cartão de Crédito')),
                  DropdownMenuItem(value: 'Investimentos', child: Text('Investimentos')),
                  DropdownMenuItem(value: 'Carteira (Dinheiro)', child: Text('Carteira / Dinheiro')),
                ],
                onChanged: (val) => setState(() => _type = val ?? 'Conta Corrente'),
              ),
              const SizedBox(height: 12),

              // Saldo Inicial / Atual com máscara dinâmica (R$ 0,00)
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: InputDecoration(
                  labelText: isCredit ? 'Fatura Atual' : 'Saldo Atual',
                  prefixText: 'R\$ ',
                  hintText: '0,00',
                ),
              ),

              // Campos específicos para Cartão de Crédito
              if (isCredit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _creditLimitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Limite do Cartão',
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _closingDayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dia Fechamento'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _dueDayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Dia Vencimento'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Cor da Conta
              Text('Cor do Cartão:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((hex) {
                  final colorInt = int.parse(hex.replaceFirst('#', '0xFF'));
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(colorInt),
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Botões Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar'),
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

