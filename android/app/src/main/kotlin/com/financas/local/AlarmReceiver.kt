package com.financas.local

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Receiver em segundo plano do Android.
 * Executa periodicamente mesmo com o aplicativo fechado, tela bloqueada ou em modo Doze,
 * consultando a API para emitir notificações de contas a vencer (estilo WhatsApp / Uber).
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "FinancasAlarm"
        const val CHANNEL_ID = "financas_alarms_channel"
        const val PREFS_NAME = "financas_background_prefs"
        const val DEFAULT_ORG_ID = "3c2ecd8cc00085cf291369725a342f5d"
        const val KEY_ORG_ID = "org_id"
        const val KEY_NOTIFIED_DATE = "last_notified_date"
        const val KEY_NOTIFIED_ITEMS = "notified_items_set"
        const val KEY_RENOTIFY_INTERVAL = "renotify_interval_ms"
        const val RC_EXACT_ALARM = 1001
        const val RC_GUARDIAN_ALARM = 1002

        fun scheduleBackgroundChecks(context: Context, orgId: String) {
            val resolvedOrg = if (orgId.isNullOrEmpty() || orgId == "default_org") DEFAULT_ORG_ID else orgId
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(KEY_ORG_ID, resolvedOrg).commit()

            val reNotifyInterval = prefs.getLong(KEY_RENOTIFY_INTERVAL, 5 * 60 * 1000L)
            val checkInterval = Math.min(15 * 60 * 1000L, reNotifyInterval).coerceAtLeast(1 * 60 * 1000L)

            Log.i(TAG, "scheduleBackgroundChecks: orgId=$resolvedOrg, checkInterval=${checkInterval / 1000}s, reNotifyInterval=${reNotifyInterval / 1000}s")

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 1. Alarme Exato Pontual via setAlarmClock (Desperta o celular com prioridade máxima, imune a Doze)
            val exactIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.financas.local.ALARM_CHECK"
            }
            val exactPending = PendingIntent.getBroadcast(
                context,
                RC_EXACT_ALARM,
                exactIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val triggerTime = System.currentTimeMillis() + checkInterval
            setExactOrInexactAlarm(context, alarmManager, triggerTime, exactPending)

            // 2. Alarme Guardião Repetitivo no Kernel do Android (RC 1002)
            try {
                val guardianIntent = Intent(context, AlarmReceiver::class.java).apply {
                    action = "com.financas.local.ALARM_GUARDIAN"
                }
                val guardianPending = PendingIntent.getBroadcast(
                    context,
                    RC_GUARDIAN_ALARM,
                    guardianIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )
                alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    checkInterval,
                    guardianPending
                )
            } catch (e: Exception) {
                Log.w(TAG, "Falha ao registrar alarme guardião: ${e.message}")
            }

            // Dispara imediatamente uma verificação em background ao sair/iniciar
            triggerImmediateCheck(context)
        }

        fun cancelBackgroundChecks(context: Context) {
            Log.i(TAG, "cancelBackgroundChecks chamado")
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().clear().commit()

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java)
            val p1 = PendingIntent.getBroadcast(
                context,
                RC_EXACT_ALARM,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val p2 = PendingIntent.getBroadcast(
                context,
                RC_GUARDIAN_ALARM,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            alarmManager.cancel(p1)
            alarmManager.cancel(p2)
        }

        fun triggerImmediateCheck(context: Context) {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.financas.local.ALARM_CHECK"
            }
            context.sendBroadcast(intent)
        }

        /**
         * Utiliza setAlarmClock no Android 5.0+ (Lollipop até Android 14/15).
         * setAlarmClock tem prioridade máxima no subsistema de energia: ele acorda a CPU
         * mesmo em Doze Mode profundo e NUNCA é atrasado ou bloqueado pelo sistema.
         */
        private fun setExactOrInexactAlarm(
            context: Context,
            alarmManager: AlarmManager,
            triggerAtMillis: Long,
            pendingIntent: PendingIntent
        ) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    val showIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val showPending = PendingIntent.getActivity(
                        context,
                        RC_EXACT_ALARM,
                        showIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                    )
                    val clockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPending)
                    alarmManager.setAlarmClock(clockInfo, pendingIntent)
                    Log.i(TAG, "setAlarmClock configurado para: ${SimpleDateFormat("HH:mm:ss", Locale.US).format(Date(triggerAtMillis))}")
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao configurar alarme exato: ${e.message}")
                try {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.i(TAG, "onReceive disparado! Action=${intent?.action}")

        if (intent?.action == Intent.ACTION_BOOT_COMPLETED || 
            intent?.action == "android.intent.action.QUICKBOOT_POWERON" || 
            intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val orgId = prefs.getString(KEY_ORG_ID, null)
            if (!orgId.isNullOrEmpty()) {
                scheduleBackgroundChecks(context, orgId)
            }
            return
        }

        // Reagenda automaticamente a próxima checagem periódica
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val reNotifyInterval = prefs.getLong(KEY_RENOTIFY_INTERVAL, 5 * 60 * 1000L)
        val checkInterval = Math.min(15 * 60 * 1000L, reNotifyInterval).coerceAtLeast(1 * 60 * 1000L)

        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val nextIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.financas.local.ALARM_CHECK"
            }
            val nextPending = PendingIntent.getBroadcast(
                context,
                RC_EXACT_ALARM,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val triggerTime = System.currentTimeMillis() + checkInterval
            setExactOrInexactAlarm(context, alarmManager, triggerTime, nextPending)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao reagendar próximo alarme: ${e.message}")
        }

        // Garante que a CPU do celular continue acordada durante a requisição de rede em background
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "FinancasApp:AlarmReceiverWakeLock"
        )
        wakeLock.acquire(30000L) // 30 segundos de segurança máxima

        val pendingResult = goAsync()
        Thread {
            try {
                checkLocalDbAndNotify(context)
            } catch (e: Exception) {
                Log.e(TAG, "Erro durante checkLocalDbAndNotify: ${e.message}", e)
            } finally {
                try {
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                    }
                } catch (_: Exception) {}
                pendingResult.finish()
            }
        }.start()
    }

    private fun checkLocalDbAndNotify(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dbFile = context.getDatabasePath("financas_local.db")
        if (!dbFile.exists()) {
            Log.d(TAG, "Banco financas_local.db ainda não foi criado.")
            return
        }

        val reNotifyInterval = prefs.getLong(KEY_RENOTIFY_INTERVAL, 5 * 60 * 1000L)
        val toleranceMs = 45 * 1000L
        val nowTime = System.currentTimeMillis()

        try {
            val db = android.database.sqlite.SQLiteDatabase.openDatabase(
                dbFile.path,
                null,
                android.database.sqlite.SQLiteDatabase.OPEN_READONLY
            )

            val cursor = db.rawQuery(
                "SELECT id, description, amount, due_date, reminder_days FROM financial_forecasts WHERE status != 'paid'",
                null
            )

            createNotificationChannel(context)
            val editor = prefs.edit()

            while (cursor.moveToNext()) {
                val id = cursor.getString(0) ?: ""
                val desc = cursor.getString(1) ?: "Previsão"
                val amount = cursor.getDouble(2)
                val dueDateStr = cursor.getString(3) ?: ""
                val reminderDays = if (cursor.isNull(4)) 30 else cursor.getInt(4)

                val days = calculateDaysRemaining(dueDateStr)

                val lastNotifiedTime = prefs.getLong("notif_time_$id", 0L)
                if (nowTime - lastNotifiedTime < (reNotifyInterval - toleranceMs)) {
                    continue
                }

                val ptBr = Locale("pt", "BR")
                val formatMoeda = NumberFormat.getCurrencyInstance(ptBr)
                val valorFormatado = formatMoeda.format(amount)
                val dataVencFormatada = formatDatePtBr(dueDateStr)

                var title: String? = null
                var body: String? = null

                if (days == 0) {
                    title = "🔔 Conta vence hoje ($dataVencFormatada)!"
                    body = "$desc • $valorFormatado\nVencimento: $dataVencFormatada (Hoje)"
                } else if (days == 1) {
                    title = "⏰ Conta vence amanhã ($dataVencFormatada)!"
                    body = "$desc • $valorFormatado\nVencimento: $dataVencFormatada (Amanhã)"
                } else if (days < 0) {
                    val atraso = -days
                    title = "⚠️ Conta em atraso há ${atraso}d ($dataVencFormatada)!"
                    body = "$desc • $valorFormatado\nVencimento: $dataVencFormatada (Venceu há $atraso dias)"
                } else if (days <= reminderDays) {
                    title = "🗓️ Vence em $days dias ($dataVencFormatada)"
                    body = "$desc • $valorFormatado\nVencimento: $dataVencFormatada (em $days dias)"
                }

                if (title != null && body != null) {
                    Log.i(TAG, "Disparando notificação offline: title='$title'")
                    showNotification(context, id.hashCode(), title, body)
                    editor.putLong("notif_time_$id", nowTime)
                }
            }

            cursor.close()
            db.close()
            editor.apply()
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao ler SQLite em background: ${e.message}", e)
        }
    }

    private fun formatDatePtBr(dateStr: String): String {
        return try {
            val cleanStr = dateStr.trim().take(10)
            val sdfIn = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val date = sdfIn.parse(cleanStr) ?: return dateStr
            val sdfOut = SimpleDateFormat("dd/MM/yyyy", Locale("pt", "BR"))
            sdfOut.format(date)
        } catch (_: Exception) {
            dateStr
        }
    }

    private fun calculateDaysRemaining(dueDateStr: String): Int {
        return try {
            val cleanStr = dueDateStr.trim().take(10)
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val due = sdf.parse(cleanStr) ?: return 999
            val calDue = Calendar.getInstance().apply {
                time = due
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val calToday = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val diff = calDue.timeInMillis - calToday.timeInMillis
            (diff / (24 * 60 * 60 * 1000)).toInt()
        } catch (_: Exception) {
            999
        }
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alarmes de Vencimento"
            val descriptionText = "Notificações de contas e previsões a vencer"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setOnlyAlertOnce(false)
            .setWhen(System.currentTimeMillis())
            .setShowWhen(true)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            val manager = NotificationManagerCompat.from(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                    manager.cancel(id) // Força reativação do alerta com som e vibração
                    manager.notify(id, builder.build())
                }
            } else {
                manager.cancel(id) // Força reativação do alerta com som e vibração
                manager.notify(id, builder.build())
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Permissão negada ao emitir notificação: ${e.message}")
        }
    }
}
