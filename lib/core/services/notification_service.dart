import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/dashboard/data/dashboard_service.dart';
import '../../features/dashboard/models/dashboard_model.dart';
import '../utils/currency_formatter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const MethodChannel _channel = MethodChannel('com.financas.local/notifications');
  static const String _keyReminderInterval = 'reminder_interval_minutes';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Timer? _periodicTimer;
  final Map<String, int> _lastNotifiedTimestamps = {};
  int _reNotifyIntervalMinutes = 5; // Padrão: 5 minutos (configurável pelo usuário no app)

  int get reminderIntervalMinutes => _reNotifyIntervalMinutes;

  /// Retorna o texto formatado para exibição na UI (ex: "15 minutos", "1 hora", "2 horas")
  static String formatIntervalText(int minutes) {
    if (minutes < 60) {
      return '$minutes minutos';
    } else if (minutes == 60) {
      return '1 hora';
    } else if (minutes % 60 == 0) {
      return '${minutes ~/ 60} horas';
    } else {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}min';
    }
  }

  /// Inicializa o serviço, carrega a preferência de tempo salva e solicita permissões
  Future<void> init() async {
    try {
      await _channel.invokeMethod('requestPermission');
      final savedStr = await _storage.read(key: _keyReminderInterval);
      if (savedStr != null && int.tryParse(savedStr) != null) {
        _reNotifyIntervalMinutes = int.parse(savedStr);
      }
      await _channel.invokeMethod('setReminderInterval', {
        'intervalMinutes': _reNotifyIntervalMinutes,
      });
    } catch (_) {
      // Ignora em plataformas não suportadas
    }
  }

  /// Salva a preferência de intervalo escolhida pelo usuário e sincroniza com o Android nativo
  Future<void> setReminderIntervalMinutes(int minutes) async {
    _reNotifyIntervalMinutes = minutes;
    _lastNotifiedTimestamps.clear(); // Limpa histórico para nova frequência entrar em vigor imediatamente
    await _storage.write(key: _keyReminderInterval, value: minutes.toString());
    try {
      await _channel.invokeMethod('setReminderInterval', {
        'intervalMinutes': minutes,
      });
    } catch (_) {}
  }

  /// Exibe uma notificação nativa na barra de status do Android (estilo WhatsApp)
  Future<void> showNotification({
    int? id,
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('showNotification', {
        'id': id ?? (DateTime.now().millisecondsSinceEpoch % 100000),
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Falha silenciosa defensiva
    }
  }

  /// Minimiza o app para segundo plano mantendo a sessão e o processo ativos (Move to Back)
  Future<void> minimizeApp() async {
    try {
      final success = await _channel.invokeMethod<bool>('minimizeApp');
      if (success != true) {
        await SystemNavigator.pop();
      }
    } catch (_) {
      await SystemNavigator.pop();
    }
  }

  /// Avalia a lista de alertas recebidos da API e dispara notificações do sistema
  Future<void> checkUpcomingAlerts(List<UpcomingAlertItem> alerts) async {
    if (alerts.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final intervalMs = _reNotifyIntervalMinutes * 60 * 1000;
    const toleranceMs = 45 * 1000; // Tolerância de 45s para compensar pequenas oscilações de timer

    for (final alert in alerts) {
      final days = alert.daysRemaining;
      final key = alert.id;

      // Se já notificou sobre esta conta há menos do intervalo configurado, não reenvia.
      final lastTime = _lastNotifiedTimestamps[key];
      if (lastTime != null && (nowMs - lastTime) < (intervalMs - toleranceMs)) {
        continue;
      }

      final formattedAmount = CurrencyFormatter.format(alert.amount);
      final dueDate = alert.dueDate;
      final dueStr = '${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}';

      String title;
      String body;

      if (days == 0) {
        title = '🔔 Conta vence hoje ($dueStr)!';
        body = '${alert.description} • $formattedAmount\nVencimento: $dueStr (Hoje)';
      } else if (days == 1) {
        title = '⏰ Conta vence amanhã ($dueStr)!';
        body = '${alert.description} • $formattedAmount\nVencimento: $dueStr (Amanhã)';
      } else if (days < 0) {
        final atraso = -days;
        title = '⚠️ Conta em atraso há ${atraso}d ($dueStr)!';
        body = '${alert.description} • $formattedAmount\nVencimento: $dueStr (Venceu há $atraso dias)';
      } else if (days <= alert.reminderDays) {
        title = '🗓️ Vence em $days dias ($dueStr)';
        body = '${alert.description} • $formattedAmount\nVencimento: $dueStr (em $days dias)';
      } else {
        continue;
      }

      await showNotification(
        id: alert.id.hashCode,
        title: title,
        body: body,
      );

      _lastNotifiedTimestamps[key] = nowMs;
    }
  }

  /// Inicia monitoramento periódico leve de alarmes na API enquanto a sessão está ativa
  void startPeriodicAlarmChecker(DashboardService dashboardService) {
    _periodicTimer?.cancel();
    final checkMinutes = _reNotifyIntervalMinutes.clamp(5, 15);
    _periodicTimer = Timer.periodic(Duration(minutes: checkMinutes), (timer) async {
      try {
        final now = DateTime.now();
        final data = await dashboardService.fetchDashboardData(month: now.month, year: now.year);
        await checkUpcomingAlerts(data.upcomingAlerts);
      } catch (_) {
        // Ignora erros de rede em segundo plano
      }
    });
  }

  void stopPeriodicAlarmChecker() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Agenda o monitoramento nativo no AlarmManager do Android (roda mesmo com o app fechado)
  Future<void> scheduleBackgroundChecks(String orgId) async {
    try {
      await _channel.invokeMethod('scheduleBackgroundChecks', {'orgId': orgId});
    } catch (_) {}
  }

  /// Cancela o monitoramento nativo no AlarmManager (ao deslogar)
  Future<void> cancelBackgroundChecks() async {
    try {
      await _channel.invokeMethod('cancelBackgroundChecks');
    } catch (_) {}
  }

  /// Dispara uma checagem imediata em background
  Future<void> triggerImmediateCheck() async {
    try {
      await _channel.invokeMethod('triggerImmediateCheck');
    } catch (_) {}
  }

  /// Verifica se o aplicativo já tem permissão para rodar livre de restrições de bateria no Android
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre a janela do sistema para o usuário liberar o app da economia de bateria (igual WhatsApp/Uber)
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}

