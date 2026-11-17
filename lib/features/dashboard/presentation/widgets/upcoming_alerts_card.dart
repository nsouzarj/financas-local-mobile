import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../planning/data/planning_service.dart';
import '../../../planning/presentation/planning_screen.dart';
import '../../../planning/presentation/settle_planned_dialog.dart';
import '../../../transactions/models/transaction_model.dart';
import '../../models/dashboard_model.dart';
import 'reminder_settings_bottom_sheet.dart';

class UpcomingAlertsCard extends StatelessWidget {
  final List<UpcomingAlertItem> alerts;
  final VoidCallback onRefresh;
  final bool hideValues;

  const UpcomingAlertsCard({
    super.key,
    required this.alerts,
    required this.onRefresh,
    required this.hideValues,
  });

  Future<void> _handleQuickConfirm(BuildContext context, UpcomingAlertItem alert) async {
    final tx = TransactionModel(
      id: alert.id,
      description: alert.description,
      amount: alert.amount,
      type: 'expense',
      date: alert.dueDate,
      dueDate: alert.dueDate,
      status: 'planned',
      reminderDays: alert.reminderDays,
    );

    final result = await SettlePlannedDialog.show(context, tx);
    if (result == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conta baixada com sucesso!'),
            backgroundColor: AppTheme.income,
          ),
        );
      }
      onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho dos Alarmes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: AppTheme.warning, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alarmes de Vencimento',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${alerts.length} ${alerts.length == 1 ? 'conta próxima' : 'contas próximas'} de vencer',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.tune_rounded, color: AppTheme.textSecondary, size: 18),
                tooltip: 'Ajustar Intervalo de Alarme',
                onPressed: () => ReminderSettingsBottomSheet.show(context),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.calendar_month, color: AppTheme.primary, size: 14),
                label: Text('Ver todas', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanningScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Lista de Alertas
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final days = alert.daysRemaining;

              String urgencyLabel;
              Color urgencyColor;
              if (days < 0) {
                urgencyLabel = 'Vencida há ${-days}d';
                urgencyColor = AppTheme.expense;
              } else if (days == 0) {
                urgencyLabel = 'Vence hoje!';
                urgencyColor = AppTheme.expense;
              } else if (days == 1) {
                urgencyLabel = 'Vence amanhã';
                urgencyColor = AppTheme.warning;
              } else {
                urgencyLabel = 'Em $days dias';
                urgencyColor = AppTheme.primary;
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: days <= 1 ? urgencyColor.withOpacity(0.5) : AppTheme.border.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: urgencyColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  urgencyLabel,
                                  style: TextStyle(
                                    color: urgencyColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatDate(alert.dueDate),
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (alert.categoryName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              alert.categoryName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            hideValues ? '••••••' : CurrencyFormatter.format(alert.amount),
                            style: TextStyle(
                              color: AppTheme.expense,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _handleQuickConfirm(context, alert),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.income.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.income.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline, color: AppTheme.income, size: 12),
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
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

