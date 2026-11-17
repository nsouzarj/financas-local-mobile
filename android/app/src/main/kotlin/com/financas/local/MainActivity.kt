package com.financas.local

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * local_auth requer FlutterFragmentActivity para exibir os diálogos biométricos nativos no Android.
 * MethodChannel com.financas.app/notifications fornece suporte nativo a alarmes do sistema na barra de notificações
 * e ocultação segura da janela (FLAG_SECURE) como em apps bancários.
 */
class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.financas.local/notifications"
    private val NOTIFICATION_CHANNEL_ID = "financas_alarms_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Oculta o conteúdo do app no multitarefa e bloqueia capturas não autorizadas (como em apps bancários)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                            result.success(true)
                        } else {
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "Finanças"
                    val body = call.argument<String>("body") ?: ""
                    showNativeNotification(id, title, body)
                    result.success(true)
                }
                "scheduleBackgroundChecks" -> {
                    val orgId = call.argument<String>("orgId") ?: "default_org"
                    AlarmReceiver.scheduleBackgroundChecks(this, orgId)
                    result.success(true)
                }
                "cancelBackgroundChecks" -> {
                    AlarmReceiver.cancelBackgroundChecks(this)
                    result.success(true)
                }
                "triggerImmediateCheck" -> {
                    AlarmReceiver.triggerImmediateCheck(this)
                    result.success(true)
                }
                "setReminderInterval" -> {
                    val minutes = call.argument<Int>("intervalMinutes") ?: 120
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    editor.putLong(AlarmReceiver.KEY_RENOTIFY_INTERVAL, minutes * 60 * 1000L)
                    // Limpa timestamps antigos para que o novo intervalo entre em vigor imediatamente
                    val allKeys = prefs.all.keys
                    for (k in allKeys) {
                        if (k.startsWith("notif_time_")) {
                            editor.remove(k)
                        }
                    }
                    editor.commit()

                    // Reagenda os alarmes com a nova frequência instantaneamente
                    val orgId = prefs.getString(AlarmReceiver.KEY_ORG_ID, null)
                    AlarmReceiver.scheduleBackgroundChecks(this, orgId ?: AlarmReceiver.DEFAULT_ORG_ID)
                    result.success(true)
                }
                "getReminderInterval" -> {
                    val prefs = getSharedPreferences(AlarmReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    val ms = prefs.getLong(AlarmReceiver.KEY_RENOTIFY_INTERVAL, 2 * 60 * 60 * 1000L)
                    result.success((ms / (60 * 1000L)).toInt())
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                startActivity(intent)
                                result.success(true)
                            } catch (_: Exception) {
                                result.success(false)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                "minimizeApp" -> {
                    // Fecha a atividade e remove completamente da tela de aplicativos abertos (Recent Apps / Multitarefa)
                    // Os alarmes em segundo plano continuam operando via AlarmReceiver (Kernel RTC_WAKEUP / setAlarmClock)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            finishAndRemoveTask()
                        } else {
                            finish()
                        }
                        result.success(true)
                    } catch (_: Exception) {
                        try {
                            moveTaskToBack(true)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alarmes de Vencimento"
            val descriptionText = "Notificações de contas e previsões a vencer"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNativeNotification(id: Int, title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
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
            val manager = NotificationManagerCompat.from(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                    manager.cancel(id) // Força reaviso com som e vibração
                    manager.notify(id, builder.build())
                }
            } else {
                manager.cancel(id) // Força reaviso com som e vibração
                manager.notify(id, builder.build())
            }
        } catch (e: SecurityException) {
            // Permissão negada pelo usuário
        }
    }
}

