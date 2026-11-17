import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';

class ReminderSettingsBottomSheet extends StatefulWidget {
  final VoidCallback? onSaved;

  const ReminderSettingsBottomSheet({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReminderSettingsBottomSheet(onSaved: onSaved),
    );
  }

  @override
  State<ReminderSettingsBottomSheet> createState() => _ReminderSettingsBottomSheetState();
}

class _ReminderSettingsBottomSheetState extends State<ReminderSettingsBottomSheet> {
  final NotificationService _notificationService = NotificationService();
  late int _selectedMinutes;
  bool _isCustom = false;
  String _customUnit = 'minutos';
  int _customValue = 45;
  bool _isBatteryOptimizationIgnored = false;

  final List<Map<String, dynamic>> _presets = [
    {
      'minutes': 5,
      'label': '5 minutos',
      'subtitle': 'Alta frequência (ideal para testes rápidos)',
      'icon': Icons.bolt_rounded,
    },
    {
      'minutes': 15,
      'label': '15 minutos',
      'subtitle': 'Avisos frequentes',
      'icon': Icons.flash_on_rounded,
    },
    {
      'minutes': 30,
      'label': '30 minutos',
      'subtitle': 'Intervalo curto de lembrete',
      'icon': Icons.timer_outlined,
    },
    {
      'minutes': 60,
      'label': '1 hora',
      'subtitle': 'Recomendado para o dia a dia',
      'icon': Icons.alarm_on_rounded,
    },
    {
      'minutes': 120,
      'label': '2 horas',
      'subtitle': 'Padrão equilibrado',
      'icon': Icons.hourglass_top_rounded,
    },
    {
      'minutes': 240,
      'label': '4 horas',
      'subtitle': 'Intervalo moderado entre avisos',
      'icon': Icons.schedule_rounded,
    },
    {
      'minutes': 480,
      'label': '8 horas',
      'subtitle': 'Lembrete discreto (manhã / tarde)',
      'icon': Icons.nights_stay_outlined,
    },
    {
      'minutes': 720,
      'label': '12 horas',
      'subtitle': '2 vezes ao dia',
      'icon': Icons.access_time_filled_rounded,
    },
    {
      'minutes': 1440,
      'label': '24 horas',
      'subtitle': '1 vez por dia',
      'icon': Icons.today_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedMinutes = _notificationService.reminderIntervalMinutes;
    final isPreset = _presets.any((p) => p['minutes'] == _selectedMinutes);
    if (!isPreset) {
      _isCustom = true;
      if (_selectedMinutes % 60 == 0) {
        _customUnit = 'horas';
        _customValue = _selectedMinutes ~/ 60;
      } else {
        _customUnit = 'minutos';
        _customValue = _selectedMinutes;
      }
    }
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    final ignored = await _notificationService.isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _isBatteryOptimizationIgnored = ignored);
  }

  Future<void> _saveInterval(int minutes) async {
    final finalMinutes = minutes.clamp(1, 10080); // mínimo 1 minuto para testes, máximo 7 dias
    await _notificationService.setReminderIntervalMinutes(finalMinutes);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏱️ Intervalo de lembrete configurado para ${NotificationService.formatIntervalText(finalMinutes)}!',
          ),
          backgroundColor: AppTheme.income,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    widget.onSaved?.call();
  }

  Future<void> _showCustomInputDialog() async {
    final controller = TextEditingController(text: _customValue.toString());
    String unit = _customUnit;

    await showDialog(
      context: context,
      builder: (dlgContext) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.border.withOpacity(0.6)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tempo Personalizado',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Digite a quantidade de tempo desejada:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ex: 45',
                        hintStyle: TextStyle(color: AppTheme.textMuted),
                        filled: true,
                        fillColor: AppTheme.surfaceLight.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppTheme.primary, width: 2),
                        ),
                      ),
                      onSubmitted: (_) {
                        final text = controller.text.trim();
                        final val = int.tryParse(text);
                        if (val != null && val > 0) {
                          final totalMinutes = unit == 'horas' ? val * 60 : val;
                          Navigator.pop(dlgContext);
                          _saveInterval(totalMinutes);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: unit,
                          dropdownColor: AppTheme.surface,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'minutos', child: Text('Minutos')),
                            DropdownMenuItem(value: 'horas', child: Text('Horas')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => unit = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgContext),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () {
                final text = controller.text.trim();
                final val = int.tryParse(text);
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Por favor, informe um tempo válido.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
                final totalMinutes = unit == 'horas' ? val * 60 : val;
                Navigator.pop(dlgContext);
                _saveInterval(totalMinutes);
              },
              child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.border.withOpacity(0.6)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de arraste
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Cabeçalho
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.timer_outlined, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Intervalo de Lembretes',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tempo para reavisar contas pendentes se dispensadas',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Card de Otimização de Bateria do Android (WhatsApp-Style)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isBatteryOptimizationIgnored
                    ? AppTheme.income.withOpacity(0.1)
                    : AppTheme.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isBatteryOptimizationIgnored
                      ? AppTheme.income.withOpacity(0.3)
                      : AppTheme.warning.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isBatteryOptimizationIgnored
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_alert_rounded,
                    color: _isBatteryOptimizationIgnored ? AppTheme.income : AppTheme.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isBatteryOptimizationIgnored
                              ? 'Segundo Plano Irrestrito Ativo'
                              : 'Economia de Bateria Detectada',
                          style: TextStyle(
                            color: _isBatteryOptimizationIgnored ? AppTheme.income : AppTheme.warning,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _isBatteryOptimizationIgnored
                              ? 'O Android não irá suspender os alarmes após longos períodos em segundo plano.'
                              : 'Toque para permitir execução contínua sem restrições (estilo WhatsApp).',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!_isBatteryOptimizationIgnored)
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.warning.withOpacity(0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        await _notificationService.requestIgnoreBatteryOptimizations();
                        await Future.delayed(const Duration(seconds: 1));
                        _checkBatteryStatus();
                      },
                      child: Text(
                        'Liberar',
                        style: TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Lista de opções
            Flexible(
              child: ListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  ..._presets.map((preset) {
                    final minutes = preset['minutes'] as int;
                    final isSelected = !_isCustom && _selectedMinutes == minutes;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: isSelected
                            ? AppTheme.primary.withOpacity(0.15)
                            : AppTheme.surfaceLight.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppTheme.primary : AppTheme.border.withOpacity(0.4),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isCustom = false;
                              _selectedMinutes = minutes;
                            });
                            _saveInterval(minutes);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  preset['icon'] as IconData,
                                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preset['label'] as String,
                                        style: TextStyle(
                                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        preset['subtitle'] as String,
                                        style: TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Opção Personalizada (Abre o diálogo com teclado ativo na hora)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    child: Material(
                      color: _isCustom
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surfaceLight.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _isCustom ? AppTheme.primary : AppTheme.border.withOpacity(0.4),
                          width: _isCustom ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () => _showCustomInputDialog(),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_calendar_rounded,
                                color: _isCustom ? AppTheme.primary : AppTheme.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isCustom
                                          ? 'Personalizado: ${NotificationService.formatIntervalText(_selectedMinutes)}'
                                          : 'Personalizado...',
                                      style: TextStyle(
                                        color: _isCustom ? AppTheme.primary : AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _isCustom
                                          ? 'Toque para alterar o tempo digitado'
                                          : 'Digite qualquer valor em minutos ou horas',
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isCustom)
                                Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20)
                              else
                                Icon(Icons.keyboard_alt_outlined, color: AppTheme.textMuted, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
