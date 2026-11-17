import 'package:flutter/material.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/skin_controller.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../planning/presentation/planning_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../transactions/presentation/transactions_screen.dart';

class MainNavScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  final BiometricService _biometricService = BiometricService();

  int _dashboardKey = 0;
  int _extratoKey = 0;
  int _reportsKey = 0;
  int _planningKey = 0;
  int _accountsKey = 0;

  List<Widget> get _screens => [
    DashboardScreen(key: ValueKey('dash_$_dashboardKey')),
    TransactionsScreen(key: ValueKey('extrato_$_extratoKey')),
    ReportsScreen(key: ValueKey('rep_$_reportsKey')),
    PlanningScreen(key: ValueKey('plan_$_planningKey')),
    AccountsScreen(key: ValueKey('acc_$_accountsKey')),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _dashboardKey++;
      if (index == 1) _extratoKey++;
      if (index == 2) _reportsKey++;
      if (index == 3) _planningKey++;
      if (index == 4) _accountsKey++;
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    _syncBackgroundAlarm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncBackgroundAlarm() async {
    final orgId = await _biometricService.getSavedOrgId();
    await NotificationService()
        .scheduleBackgroundChecks(orgId ?? 'default_org');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _syncBackgroundAlarm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SkinController.instance,
      builder: (context, _) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          } else {
            // Minimiza o aplicativo mantendo a sessão e alarmes ativos
            NotificationService().minimizeApp();
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(
                  color: AppTheme.border.withOpacity(0.6),
                  width: 1,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabTapped,
              backgroundColor: AppTheme.surface,
              selectedItemColor: AppTheme.primary,
              unselectedItemColor: AppTheme.textMuted,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 11,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard_rounded),
                  label: 'Início',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Extrato',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  activeIcon: Icon(Icons.analytics_rounded),
                  label: 'Relatórios',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.event_note_outlined),
                  activeIcon: Icon(Icons.event_note_rounded),
                  label: 'Planejamento',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet_rounded),
                  label: 'Contas & Cat.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
