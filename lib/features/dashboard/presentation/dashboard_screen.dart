import 'package:flutter/material.dart';
import '../../../core/controllers/data_refresh_controller.dart';
import '../../../core/controllers/value_visibility_controller.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../../core/theme/skin_picker_bottom_sheet.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../backup/presentation/backup_bottom_sheet.dart';
import '../data/dashboard_service.dart';
import '../models/dashboard_model.dart';
import 'widgets/cash_flow_chart.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/reminder_settings_bottom_sheet.dart';
import 'widgets/upcoming_alerts_card.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/biometric_lock_screen.dart';
import '../../auth/presentation/login_screen.dart';
import '../../planning/presentation/planning_screen.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/presentation/new_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  final BiometricService _biometricService = BiometricService();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  DashboardData? _data;
  bool _isBiometricActive = false;
  String _workspaceName = 'Finanças Pessoais';

  @override
  void initState() {
    super.initState();
    DataRefreshController.instance.addListener(_onDataChanged);
    _loadData();
    _loadWorkspaceName();
    _checkBiometricStatus();
    _initNotifications();
  }

  @override
  void dispose() {
    DataRefreshController.instance.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _loadData();
  }

  Future<void> _loadWorkspaceName() async {
    final authService = AuthService();
    final name = await authService.getCurrentWorkspaceName();
    if (mounted) setState(() => _workspaceName = name);
  }

  Future<void> _initNotifications() async {
    final notif = NotificationService();
    await notif.init();
    notif.startPeriodicAlarmChecker(_dashboardService);
    final orgId = await _biometricService.getSavedOrgId();
    await notif.scheduleBackgroundChecks(orgId ?? 'default_org');
  }

  Future<void> _checkBiometricStatus() async {
    final active = await _biometricService.isBiometricEnabledByUser();
    if (mounted) setState(() => _isBiometricActive = active);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _dashboardService.fetchDashboardData(
        month: _selectedDate.month,
        year: _selectedDate.year,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });

      // Dispara as notificações nativas estilo WhatsApp na barra do Android para contas a vencer
      if (data.upcomingAlerts.isNotEmpty) {
        NotificationService().checkUpcomingAlerts(data.upcomingAlerts);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao conectar ao servidor.';
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    });
    _loadData();
  }

  void _setTodayMonth() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadData();
  }

  Future<void> _toggleBiometrics() async {
    final canUse = await _biometricService.canAuthenticateWithBiometrics();
    if (!canUse && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Este aparelho não possui biometria ou digital cadastrada nas configurações do Android.'),
          backgroundColor: AppTheme.expense,
        ),
      );
      return;
    }

    if (!_isBiometricActive) {
      // Ao ativar, valida com o sensor para certificar que funciona no hardware do aparelho
      final didAuth = await _biometricService.authenticate(
        customMessage: 'Toque no sensor biométrico para confirmar a ativação',
      );

      if (!didAuth) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('A validação biométrica não foi concluída. O bloqueio não foi ativado.'),
              backgroundColor: AppTheme.expense,
            ),
          );
        }
        return;
      }

      await _biometricService.setBiometricsEnabled(true);
      if (mounted) {
        setState(() => _isBiometricActive = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Desbloqueio por digital ativado e validado com sucesso!'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
    } else {
      await _biometricService.setBiometricsEnabled(false);
      if (mounted) {
        setState(() => _isBiometricActive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Desbloqueio por digital desativado. O app abrirá direto.'),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    NotificationService().stopPeriodicAlarmChecker();
    await NotificationService().cancelBackgroundChecks();
    await _biometricService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showExitOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.border.withOpacity(0.6)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Opções do Aplicativo & Saída',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Gerencie alarmes, saída segura e bloqueio:',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 14),

                // Ajustar Intervalo de Lembretes / Alarmes
                Material(
                  color: AppTheme.surfaceLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      ReminderSettingsBottomSheet.show(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.timer_outlined, color: AppTheme.warning, size: 21),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Intervalo de Lembretes',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        NotificationService.formatIntervalText(
                                          NotificationService().reminderIntervalMinutes,
                                        ),
                                        style: TextStyle(
                                          color: AppTheme.warning,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ajustar tempo para reavisar contas pendentes.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Opção 1: Fechar / Sair mantendo o processo em background
                Material(
                  color: AppTheme.surfaceLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      // Garante o agendamento do serviço nativo em background antes de fechar a janela
                      final orgId = await _biometricService.getSavedOrgId();
                      await NotificationService().scheduleBackgroundChecks(orgId ?? 'default_org');
                      // Fecha e remove a janela visual da tela/multitarefa
                      await NotificationService().minimizeApp();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.exit_to_app_rounded, color: AppTheme.primary, size: 21),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sair do App (Alarmes Ativos)',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fecha e limpa a tela de apps abertos, mantendo os alarmes verificando contas a vencer.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Opção 2: Bloquear com Biometria
                Material(
                  color: AppTheme.surfaceLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (lockCtx) => BiometricLockScreen(
                            onAuthenticated: () {
                              if (Navigator.canPop(lockCtx)) {
                                Navigator.pop(lockCtx);
                              }
                            },
                            onFallbackToPassword: () => _logout(),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.income.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.fingerprint_rounded, color: AppTheme.income, size: 21),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bloquear com Biometria',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Protege o acesso imediatamente com sua digital sem perder o login.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Opção 3: Desconectar (Logout Completo)
                Material(
                  color: AppTheme.expense.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _logout();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppTheme.expense.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.logout_rounded, color: AppTheme.expense, size: 21),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Desconectar da Conta',
                                  style: TextStyle(
                                    color: AppTheme.expense,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Encerra a sessão e apaga as credenciais salvas no aparelho.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatAmount(double val) {
    if (ValueVisibilityController.instance.hideValues) return '••••••';
    return CurrencyFormatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ValueVisibilityController.instance,
        SkinController.instance,
      ]),
      builder: (context, _) {
        final hideValues = ValueVisibilityController.instance.hideValues;
        final formattedMonthName = CurrencyFormatter.formatMonthYear(_selectedDate);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _workspaceName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Painel Financeiro • Offline',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
            actions: [
              const EyeVisibilityButton(),
              IconButton(
                icon: Icon(Icons.shield_outlined, color: AppTheme.textSecondary, size: 21),
                tooltip: 'Backups & Segurança',
                onPressed: () => BackupBottomSheet.show(context),
              ),
              IconButton(
                icon: Icon(Icons.palette_outlined, color: AppTheme.textSecondary, size: 21),
                tooltip: 'Temas & Cores (Skins)',
                onPressed: () => SkinPickerBottomSheet.show(context),
              ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.event_note_rounded, color: AppTheme.textSecondary, size: 21),
                if ((_data?.upcomingAlerts.length ?? 0) > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_data!.upcomingAlerts.length}',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Planejamento Futuro',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlanningScreen()),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: Icon(
              Icons.fingerprint,
              color: _isBiometricActive ? AppTheme.primary : AppTheme.textMuted,
              size: 22,
            ),
            tooltip: _isBiometricActive ? 'Biometria ativa' : 'Ativar biometria',
            onPressed: _toggleBiometrics,
          ),
          IconButton(
            icon: Icon(Icons.power_settings_new, color: AppTheme.textSecondary, size: 21),
            tooltip: 'Opções de saída',
            onPressed: _showExitOptions,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color(0xFF0F172A),
        tooltip: 'Novo Lançamento',
        child: const Icon(Icons.add, size: 24),
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NewTransactionScreen()),
          );
          if (created == true) _loadData();
        },
      ),
      body: Column(
        children: [
          // Barra de Navegação de Mês
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
            ),
          ),

          // Conteúdo do Dashboard
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off, size: 48, color: AppTheme.expense),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.surface,
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          children: [
                            // 1. Cartão Principal: Saldo Geral
                            _buildBalanceCard(_data!.totalBalance),
                            const SizedBox(height: 12),

                            // 2. Grid de Métricas: Receitas, Despesas e Balanço Líquido
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Receitas',
                                    amount: _data!.monthlyIncome,
                                    color: AppTheme.income,
                                    icon: Icons.arrow_downward_rounded,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildMetricCard(
                                    title: 'Despesas',
                                    amount: _data!.monthlyExpenses,
                                    color: AppTheme.expense,
                                    icon: Icons.arrow_upward_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Cartão de Balanço do Mês (Receitas - Despesas)
                            _buildNetBalanceCard(_data!.netBalance),
                            const SizedBox(height: 16),

                            // Gráfico 1: Fluxo de Caixa (Receitas vs Despesas)
                            CashFlowChartWidget(
                              income: _data!.monthlyIncome,
                              expenses: _data!.monthlyExpenses,
                              hideValues: hideValues,
                            ),
                            const SizedBox(height: 16),

                            // 3. Alarmes de Vencimento do Planejamento
                            if (_data!.upcomingAlerts.isNotEmpty) ...[
                              UpcomingAlertsCard(
                                alerts: _data!.upcomingAlerts,
                                onRefresh: _loadData,
                                hideValues: hideValues,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 4. Alerta de Contas Pendentes Gerais (se houver)
                            if (_data!.pendingBills.count > 0) ...[
                              _buildPendingBillsAlert(_data!.pendingBills),
                              const SizedBox(height: 16),
                            ],

                            // Gráfico 2: Gastos por Categoria (Donut Interativo + Lista Expandida)
                            CategoryDonutChartWidget(
                              categories: _data!.categoryBreakdown,
                              totalExpenses: _data!.monthlyExpenses,
                              hideValues: hideValues,
                            ),
                            const SizedBox(height: 20),

                            // 5. Últimos Lançamentos Recentes
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Últimos Lançamentos',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formattedMonthName,
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_data!.recentTransactions.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Center(
                                  child: Text(
                                    'Nenhum lançamento registrado neste mês.',
                                    style: TextStyle(color: AppTheme.textMuted),
                                  ),
                                ),
                              )
                            else
                              ..._data!.recentTransactions.map((tx) => _buildRecentTransactionCard(tx)),
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

  Widget _buildBalanceCard(double balance) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            AppTheme.primary.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saldo Total em Contas',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(balance),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            color.withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetBalanceCard(double netBalance) {
    final isPositive = netBalance >= 0;
    final color = isPositive ? AppTheme.income : AppTheme.expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22), width: 1.2),
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            color.withOpacity(0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Balanço do Mês',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            _formatAmount(netBalance),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBillsAlert(PendingBillsSummary pending) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pending.count} conta(s) pendente(s)',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Totalizando ${_formatAmount(pending.total)} a pagar',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionCard(TransactionModel tx) {
    final isIncome = tx.isIncome;
    final color = isIncome ? AppTheme.income : AppTheme.expense;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final updated = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => NewTransactionScreen(transaction: tx)),
          );
          if (updated == true) _loadData();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border.withOpacity(0.6)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      '${tx.categoryName ?? 'Geral'} • ${tx.accountName ?? 'Conta'} • ${CurrencyFormatter.formatDate(tx.date)}',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ${_formatAmount(tx.amount)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tx.isPaid ? AppTheme.income.withOpacity(0.12) : AppTheme.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tx.isPaid ? 'Pago' : 'Pendente',
                      style: TextStyle(
                        color: tx.isPaid ? AppTheme.income : AppTheme.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
