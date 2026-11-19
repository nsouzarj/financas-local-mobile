import 'package:flutter/material.dart';
import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/controllers/value_visibility_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/presentation/widgets/reminder_settings_bottom_sheet.dart';
import '../../transactions/models/transaction_model.dart';
import '../data/planning_service.dart';
import 'planning_form_dialog.dart';
import 'settle_planned_dialog.dart';

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
  final PlanningService _planningService = PlanningService();

  DateTime _selectedDate = DateTime.now();
  bool _isAllPeriod = false;
  bool _isLoading = true;
  bool _isCopying = false;
  String? _error;
  List<TransactionModel> _plannedTransactions = [];

  @override
  void initState() {
    super.initState();
    DataRefreshController.instance.addListener(_onDataChanged);
    _loadPlanned();
  }

  @override
  void dispose() {
    DataRefreshController.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadPlanned();
  }

  Future<void> _loadPlanned() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? start;
      String? end;

      if (!_isAllPeriod) {
        final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        start = CurrencyFormatter.formatDateToApi(firstDay);
        end = CurrencyFormatter.formatDateToApi(lastDay);
      }

      final data = await _planningService.getPlannedTransactions(
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      setState(() {
        _plannedTransactions = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar planejamento.';
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _isAllPeriod = false;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
    _loadPlanned();
  }

  void _nextMonth() {
    setState(() {
      _isAllPeriod = false;
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
    _loadPlanned();
  }

  void _toggleAllPeriod() {
    setState(() {
      _isAllPeriod = !_isAllPeriod;
    });
    _loadPlanned();
  }

  Future<void> _openPlanningForm([TransactionModel? tx]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PlanningFormDialog(plannedTx: tx),
    );

    if (result == true) {
      _loadPlanned();
    }
  }

  Future<void> _confirmPayment(TransactionModel tx) async {
    final result = await SettlePlannedDialog.show(context, tx);
    if (result == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lançamento baixado com sucesso! Saldo recalculado.'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
      _loadPlanned();
    }
  }

  Future<void> _deletePlanned(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Excluir Previsão?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja remover a previsão "${tx.description}"?',
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
      final success = await _planningService.deletePlanned(tx.id);
      if (success) {
        _loadPlanned();
      }
    }
  }

  Future<void> _copySingleToNextMonth(TransactionModel tx) async {
    if (_isCopying) return;
    setState(() => _isCopying = true);
    try {
      final newDate = await _planningService.copyToNextMonth(tx);
      if (!mounted) return;
      if (newDate != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${tx.description}" copiado para ${CurrencyFormatter.formatDate(newDate)} (dia útil)!',
            ),
            backgroundColor: AppTheme.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível copiar a previsão.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao copiar previsão para o próximo mês.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  Future<void> _copyAllToNextMonth() async {
    if (_isCopying || _plannedTransactions.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Copiar Mês p/ Próximo?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Deseja copiar todas as ${_plannedTransactions.length} previsão(ões) listadas para o próximo mês?\n\nDatas que caírem em sábado ou domingo serão ajustadas automaticamente para segunda-feira (dia útil).',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Copiar Tudo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCopying = true);
    try {
      final count = await _planningService.copyBatchToNextMonth(_plannedTransactions);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count previsão(ões) copiada(s) para o próximo mês (em dias úteis)!'),
          backgroundColor: AppTheme.income,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao copiar previsões em lote.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCopying = false);
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
        final monthLabel = CurrencyFormatter.formatMonthYear(_selectedDate);

        final totalIncome = _plannedTransactions
            .where((t) => t.isIncome)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        final totalExpense = _plannedTransactions
            .where((t) => t.isExpense)
            .fold<double>(0.0, (sum, t) => sum + t.amount);
        final netPlanned = totalIncome - totalExpense;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Planejamento Futuro', overflow: TextOverflow.ellipsis),
            actions: [
              const EyeVisibilityButton(),
              IconButton(
                icon: Icon(
                  Icons.copy_all_rounded,
                  color: _plannedTransactions.isEmpty || _isCopying
                      ? AppTheme.textMuted
                      : AppTheme.primary,
                  size: 22,
                ),
                tooltip: 'Copiar previsões para o próximo mês (dias úteis)',
                onPressed: (_plannedTransactions.isEmpty || _isCopying)
                    ? null
                    : _copyAllToNextMonth,
              ),
              IconButton(
                icon: Icon(
                  Icons.all_inclusive,
                  color: _isAllPeriod ? AppTheme.primary : AppTheme.textSecondary,
                ),
                tooltip: _isAllPeriod ? 'Filtrar por mês' : 'Ver todo o período',
                onPressed: _toggleAllPeriod,
          ),
          IconButton(
            icon: Icon(Icons.timer_outlined, color: AppTheme.textSecondary, size: 22),
            tooltip: 'Intervalo de Alarme',
            onPressed: () => ReminderSettingsBottomSheet.show(context),
          ),
          IconButton(
            icon: Icon(Icons.add_circle, color: AppTheme.primary, size: 26),
            tooltip: 'Nova Previsão',
            onPressed: () => _openPlanningForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de Período
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isAllPeriod)
                  Expanded(
                    child: Center(
                      child: Text(
                        'Todo o Planejamento Futuro',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  )
                else ...[
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    monthLabel,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

          // Cards de Resumo do Planejamento
          Container(
            color: AppTheme.surface.withOpacity(0.5),
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Despesas Prev.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
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
                Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.6)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Receitas Prev.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.formatOrHide(totalIncome),
                            style: TextStyle(color: AppTheme.income, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 26, color: AppTheme.border.withOpacity(0.6)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Resultado', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.formatOrHide(netPlanned),
                          style: TextStyle(
                            color: netPlanned >= 0 ? AppTheme.primary : AppTheme.expense,
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

          // Aviso Didático
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Previsões não afetam o saldo real das suas contas até que você clique em "Baixar".',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Previsões
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
                            ElevatedButton(onPressed: _loadPlanned, child: const Text('Tentar novamente')),
                          ],
                        ),
                      )
                    : _plannedTransactions.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_available, size: 52, color: AppTheme.textMuted.withOpacity(0.4)),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Nenhuma previsão futura registrada para este período.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Toque no botão + no topo para cadastrar.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            backgroundColor: AppTheme.surface,
                            onRefresh: _loadPlanned,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                              itemCount: _plannedTransactions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _buildPlannedCard(_plannedTransactions[index]);
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

  Widget _buildPlannedCard(TransactionModel tx) {
    final isIncome = tx.isIncome;
    final color = isIncome ? AppTheme.income : AppTheme.expense;
    final dueDate = tx.dueDate ?? tx.date;
    final formattedDueDate = CurrencyFormatter.formatDate(dueDate);

    // Calcular dias restantes
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDayOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final daysRemaining = dueDayOnly.difference(today).inDays;

    String urgencyText;
    Color urgencyColor;
    if (daysRemaining < 0) {
      urgencyText = 'Vencida há ${-daysRemaining}d';
      urgencyColor = AppTheme.expense;
    } else if (daysRemaining == 0) {
      urgencyText = 'Vence hoje!';
      urgencyColor = AppTheme.expense;
    } else if (daysRemaining == 1) {
      urgencyText = 'Vence amanhã';
      urgencyColor = AppTheme.warning;
    } else if (daysRemaining <= 7) {
      urgencyText = 'Vence em $daysRemaining dias';
      urgencyColor = AppTheme.warning;
    } else {
      urgencyText = 'Em $daysRemaining dias';
      urgencyColor = AppTheme.primary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPlanningForm(tx),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: daysRemaining <= 1 ? urgencyColor.withOpacity(0.4) : AppTheme.border.withOpacity(0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha 1: Ícone + Descrição/Conta/Categoria + Valor
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (tx.categoryName != null) ...[
                              Flexible(
                                child: Text(
                                  tx.categoryName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ),
                              if (tx.accountName != null)
                                Text(' • ', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                            ],
                            if (tx.accountName != null)
                              Flexible(
                                child: Text(
                                  tx.accountName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatOrHide(tx.amount)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(height: 1, thickness: 1, color: AppTheme.border.withOpacity(0.4)),
              const SizedBox(height: 10),

              // Linha 2: Badges (Vencimento, Urgência, Alarme) + Botões de Ação (Baixar, Editar, Excluir)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Badge de Vencimento
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 10, color: urgencyColor),
                              const SizedBox(width: 4),
                              Text(
                                formattedDueDate,
                                style: TextStyle(
                                  color: urgencyColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Badge de Urgência
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: urgencyColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            urgencyText,
                            style: TextStyle(
                              color: urgencyColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Badge de Alarme (se configurado)
                        if (tx.reminderDays != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_active, color: AppTheme.primary, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  '${tx.reminderDays}d',
                                  style: TextStyle(
                                    color: AppTheme.primary,
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
                  const SizedBox(width: 6),
                  // Ações contidas dentro do card
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botão Confirmar / Baixar
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmPayment(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.income.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.income.withOpacity(0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, color: AppTheme.income, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'Baixar',
                                  style: TextStyle(
                                    color: AppTheme.income,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Botão Duplicar p/ Próximo Mês (Dia Útil)
                      Material(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _isCopying ? null : () => _copySingleToNextMonth(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.copy_rounded, color: AppTheme.primary, size: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      // Botão Editar
                      Material(
                        color: AppTheme.surfaceLight.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _openPlanningForm(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botão Excluir
                      Material(
                        color: AppTheme.expense.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () => _deletePlanned(tx),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.delete_outline, color: AppTheme.expense, size: 15),
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

