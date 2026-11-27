package ec.edu.espoch.pawtrack

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Bundle
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ============================================================================
// ACTIVIDAD PRINCIPAL DE ANDROID (MainActivity)
// 1. Crea el canal de notificaciones de alta prioridad ("pawtrack_notifications").
// 2. Expone un MethodChannel nativo para:
//    - Mostrar notificaciones reales en la barra de estado de Android.
//    - Reconocimiento de voz nativo en español (Speech-to-Text) para PawBot.
// ============================================================================
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL_ID = "pawtrack_notifications"
        const val METHOD_CHANNEL = "ec.edu.espoch.pawtrack/notifications"
        const val VOICE_REQUEST_CODE = 9021
    }

    private var pendingVoiceResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showSystemNotification" -> {
                        val title = call.argument<String>("title") ?: "PawTrack"
                        val body = call.argument<String>("body") ?: ""
                        val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                        showAndroidNotification(id, title, body)
                        result.success(true)
                    }
                    "startVoiceInput" -> {
                        startVoiceRecognition(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Inicia el micrófono nativo de Android para dictar preguntas por voz a PawBot
    private fun startVoiceRecognition(result: MethodChannel.Result) {
        if (pendingVoiceResult != null) {
            pendingVoiceResult?.success(null)
            pendingVoiceResult = null
        }
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-EC")
                putExtra(RecognizerIntent.EXTRA_PROMPT, "Habla ahora para preguntarle a PawBot...")
            }
            pendingVoiceResult = result
            startActivityForResult(intent, VOICE_REQUEST_CODE)
        } catch (e: Exception) {
            pendingVoiceResult = null
            result.error("VOICE_UNAVAILABLE", "El reconocimiento de voz no está disponible en este dispositivo.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VOICE_REQUEST_CODE) {
            val callback = pendingVoiceResult
            pendingVoiceResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                val spokenText = if (!matches.isNullOrEmpty()) matches[0] else ""
                callback?.success(spokenText)
            } else {
                callback?.success("")
            }
        }
    }

    // Registra el canal de notificaciones en el sistema operativo Android
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alertas y Notificaciones PawTrack",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificaciones de nuevos reportes, cambios de estado y próximas vacunas"
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    // Construye y lanza una notificación nativa en la barra superior de Android
    private fun showAndroidNotification(id: Int, title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(this, id, intent, pendingFlags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
        }

        val largeLogo = BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(largeLogo)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        manager.notify(id, builder.build())
    }
}
