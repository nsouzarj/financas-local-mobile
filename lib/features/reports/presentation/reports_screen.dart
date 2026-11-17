import 'package:flutter/material.dart';
import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/controllers/value_visibility_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/reports_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsService _reportsService = ReportsService();
  ReportPeriod _selectedPeriod = ReportPeriod.currentMonth;
  bool _isLoading = true;
  String? _error;
  ReportSummary? _report;
  int _categoryTab = 0; // 0 = Despesas, 1 = Receitas, 2 = Patrimônio/Contas

  @override
  void initState() {
    super.initState();
    DataRefreshController.instance.addListener(_onDataChanged);
    _loadReport();
  }

  @override
  void dispose() {
    DataRefreshController.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _reportsService.getReport(_selectedPeriod);
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao gerar relatório: $e';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(ReportPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    _loadReport();
  }

  String _formatAmount(double val) {
    if (ValueVisibilityController.instance.hideValues) return '••••••';
    return CurrencyFormatter.format(val);
  }

  Color _parseHexColor(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ValueVisibilityController.instance,
        SkinController.instance,
      ]),
      builder: (context, _) {
        final currentSkin = SkinController.instance.currentSkin;
        final primaryColor = currentSkin.primary;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Relatórios & Análise'),
            actions: [
              const EyeVisibilityButton(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar Dados',
                onPressed: _loadReport,
              ),
            ],
          ),
          body: Column(
            children: [
              // Seletor de Período (Chips)
              _buildPeriodSelector(primaryColor),

              // Conteúdo do Relatório
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: AppTheme.expense, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                        color: AppTheme.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadReport,
                                    child: const Text('Tentar Novamente'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _report == null
                            ? const SizedBox.shrink()
                            : RefreshIndicator(
                                color: primaryColor,
                                backgroundColor: AppTheme.surface,
                                onRefresh: _loadReport,
                                child: ListView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  children: [
                                    // 1. Resumo Geral de Entradas vs Saídas
                                    _buildKpiCards(_report!, primaryColor),
                                    const SizedBox(height: 16),

                                    // 2. Taxa de Poupança / Economia
                                    _buildSavingsRateCard(
                                        _report!, primaryColor),
                                    const SizedBox(height: 20),

                                    // 3. Evolução Mensal (Receitas vs Despesas)
                                    _buildMonthlyEvolutionSection(
                                        _report!, primaryColor),
                                    const SizedBox(height: 20),

                                    // 4. Seletor de Abas de Detalhamento
                                    _buildDetailTabs(primaryColor),
                                    const SizedBox(height: 14),

                                    // 5. Lista detalhada conforme a aba selecionada
                                    if (_categoryTab == 0)
                                      _buildExpenseCategoriesSection(_report!)
                                    else if (_categoryTab == 1)
                                      _buildIncomeCategoriesSection(_report!)
                                    else
                                      _buildAccountsSection(_report!),

                                    const SizedBox(height: 32),
                                  ],
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.border.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildPeriodChip('Mês Atual', ReportPeriod.currentMonth, primaryColor),
            const SizedBox(width: 8),
            _buildPeriodChip('3 Meses', ReportPeriod.last3Months, primaryColor),
            const SizedBox(width: 8),
            _buildPeriodChip('6 Meses', ReportPeriod.last6Months, primaryColor),
            const SizedBox(width: 8),
            _buildPeriodChip('Ano Atual', ReportPeriod.currentYear, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(
      String label, ReportPeriod period, Color primaryColor) {
    final isSelected = _selectedPeriod == period;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: AppTheme.surfaceLight,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : AppTheme.border.withOpacity(0.4),
          width: 1,
        ),
      ),
      onSelected: (_) => _onPeriodChanged(period),
    );
  }

  Widget _buildKpiCards(ReportSummary report, Color primaryColor) {
    return Column(
      children: [
        // Linha 1: Receitas e Despesas lado a lado
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Receitas',
                value: _formatAmount(report.totalIncome),
                icon: Icons.arrow_upward_rounded,
                color: AppTheme.income,
                subtitle: 'Total no período',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                title: 'Despesas',
                value: _formatAmount(report.totalExpense),
                icon: Icons.arrow_downward_rounded,
                color: AppTheme.expense,
                subtitle: 'Total de saídas',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Linha 2: Saldo Líquido
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: (report.netBalance >= 0 ? AppTheme.income : AppTheme.expense)
                  .withOpacity(0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (report.netBalance >= 0
                          ? AppTheme.income
                          : AppTheme.expense)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  report.netBalance >= 0
                      ? Icons.savings_outlined
                      : Icons.warning_amber_rounded,
                  color: report.netBalance >= 0
                      ? AppTheme.income
                      : AppTheme.expense,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Líquido do Período',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatAmount(report.netBalance),
                      style: TextStyle(
                        color: report.netBalance >= 0
                            ? AppTheme.income
                            : AppTheme.expense,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (report.netBalance >= 0
                          ? AppTheme.income
                          : AppTheme.expense)
                      .withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.netBalance >= 0 ? 'Superávit' : 'Déficit',
                  style: TextStyle(
                    color: report.netBalance >= 0
                        ? AppTheme.income
                        : AppTheme.expense,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsRateCard(ReportSummary report, Color primaryColor) {
    final rate = report.savingsRate.clamp(0.0, 100.0);
    final isPositive = report.netBalance >= 0;

    String statusText;
    Color statusColor;

    if (!isPositive) {
      statusText = 'Despesas superam receitas no período';
      statusColor = AppTheme.expense;
    } else if (rate >= 30) {
      statusText = 'Excelente retenção financeira';
      statusColor = AppTheme.income;
    } else if (rate >= 15) {
      statusText = 'Bom ritmo de poupança';
      statusColor = primaryColor;
    } else {
      statusText = 'Ritmo cauteloso de poupança';
      statusColor = AppTheme.warning;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart_outline_rounded,
                      color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Taxa de Poupança',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: isPositive ? (rate / 100.0) : 0.02,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 11),
              ),
              Text(
                'Economizado: ${_formatAmount(report.netBalance > 0 ? report.netBalance : 0.0)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyEvolutionSection(
      ReportSummary report, Color primaryColor) {
    if (report.evolution.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evolução dos Meses',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(AppTheme.income, 'Receita'),
                  const SizedBox(width: 10),
                  _buildLegendDot(AppTheme.expense, 'Despesa'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Encontra valor máximo para normalização das barras
          Builder(
            builder: (context) {
              double maxVal = 1.0;
              for (final ev in report.evolution) {
                if (ev.income > maxVal) maxVal = ev.income;
                if (ev.expense > maxVal) maxVal = ev.expense;
              }

              return Column(
                children: report.evolution.map((ev) {
                  final incomeRatio = (ev.income / maxVal).clamp(0.0, 1.0);
                  final expenseRatio = (ev.expense / maxVal).clamp(0.0, 1.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ev.label.toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Saldo: ${_formatAmount(ev.net)}',
                              style: TextStyle(
                                color: ev.net >= 0
                                    ? AppTheme.income
                                    : AppTheme.expense,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Barra de Receitas
                        Row(
                          children: [
                            SizedBox(
                              width: 55,
                              child: Text(
                                _formatAmount(ev.income),
                                style: TextStyle(
                                  color: AppTheme.income,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor:
                                        incomeRatio > 0 ? incomeRatio : 0.01,
                                    child: Container(
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: AppTheme.income,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Barra de Despesas
                        Row(
                          children: [
                            SizedBox(
                              width: 55,
                              child: Text(
                                _formatAmount(ev.expense),
                                style: TextStyle(
                                  color: AppTheme.expense,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor:
                                        expenseRatio > 0 ? expenseRatio : 0.01,
                                    child: Container(
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: AppTheme.expense,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDetailTabs(Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.5), width: 1),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTabButton('Despesas', 0, primaryColor),
          ),
          Expanded(
            child: _buildSubTabButton('Receitas', 1, primaryColor),
          ),
          Expanded(
            child: _buildSubTabButton('Patrimônio', 2, primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabButton(String label, int index, Color primaryColor) {
    final isSelected = _categoryTab == index;
    return InkWell(
      onTap: () => setState(() => _categoryTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseCategoriesSection(ReportSummary report) {
    if (report.expenseCategories.isEmpty) {
      return _buildEmptySection(
        'Nenhuma despesa registrada neste período.',
        Icons.receipt_long_outlined,
      );
    }

    return Column(
      children: report.expenseCategories.map((cat) {
        final catColor = _parseHexColor(cat.color, AppTheme.expense);
        return _buildCategoryItemTile(cat, catColor);
      }).toList(),
    );
  }

  Widget _buildIncomeCategoriesSection(ReportSummary report) {
    if (report.incomeCategories.isEmpty) {
      return _buildEmptySection(
        'Nenhuma receita registrada neste período.',
        Icons.savings_outlined,
      );
    }

    return Column(
      children: report.incomeCategories.map((cat) {
        final catColor = _parseHexColor(cat.color, AppTheme.income);
        return _buildCategoryItemTile(cat, catColor);
      }).toList(),
    );
  }

  Widget _buildCategoryItemTile(CategoryReportItem cat, Color itemColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: itemColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cat.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${cat.count}x',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              const SizedBox(width: 12),
              Text(
                _formatAmount(cat.total),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: itemColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${cat.percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: itemColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (cat.percentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(itemColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(ReportSummary report) {
    if (report.accounts.isEmpty) {
      return _buildEmptySection(
        'Nenhuma conta cadastrada.',
        Icons.account_balance_outlined,
      );
    }

    return Column(
      children: report.accounts.map((acc) {
        final accColor = _parseHexColor(acc.color, AppTheme.primary);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.border.withOpacity(0.4), width: 1),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_balance_rounded,
                        color: accColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acc.name,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          acc.typeLabel,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatAmount(acc.balance),
                        style: TextStyle(
                          color: acc.balance >= 0
                              ? AppTheme.textPrimary
                              : AppTheme.expense,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${acc.percentage.toStringAsFixed(1)}% do patrimônio',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (acc.percentage / 100.0).clamp(0.0, 1.0),
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: AlwaysStoppedAnimation<Color>(accColor),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptySection(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: AppTheme.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

