package com.jarvis.mobile.jarvis_mobile

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Registers this app's two native MethodChannels — the Play Integrity
 * bridge (see integrityChannelName) and the Notification-Hub bridge (see
 * notificationHubChannelName) — each in its own configure*Channel method,
 * kept in one class since FlutterActivity's configureFlutterEngine is the
 * one place Flutter plugins/channels get wired up per Activity instance.
 */
class MainActivity : FlutterActivity() {
    private val integrityChannelName = "com.jarvis.mobile.jarvis_mobile/integrity"
    private val notificationHubChannelName = "com.jarvis.mobile.jarvis_mobile/notification_hub"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureIntegrityChannel(flutterEngine)
        configureNotificationHubChannel(flutterEngine)
    }

    /**
     * App-Integritäts-Check (Google Play Integrity API) — bridges a single
     * MethodChannel call from Dart (see app_integrity_service.dart) to the
     * native Play Integrity SDK, since it has no Dart/Flutter API of its own.
     *
     * Uses the "classic" IntegrityManager (single-call requestIntegrityToken),
     * not the newer two-step StandardIntegrityManager — simpler for a one-shot
     * check like this, and still supported as of this writing. Google's own
     * migration guidance may have moved on by the time this runs; check the
     * current Play Integrity docs if requestIntegrityToken ever starts
     * returning deprecation warnings.
     *
     * Requires a real Google Cloud project linked to Google Play Console (its
     * "cloud project number", entered by the user in Einstellungen — see
     * README) before this returns anything meaningful; without it,
     * requestIntegrityToken fails and the MethodChannel call errors, which
     * AppIntegrityService treats as "integrity check unavailable" rather than
     * a hard failure.
     */
    private fun configureIntegrityChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, integrityChannelName).setMethodCallHandler { call, result ->
            if (call.method != "requestIntegrityToken") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val nonce = call.argument<String>("nonce")
            val cloudProjectNumberRaw = call.argument<String>("cloudProjectNumber")
            val cloudProjectNumber = cloudProjectNumberRaw?.toLongOrNull()
            if (nonce.isNullOrEmpty() || cloudProjectNumber == null) {
                result.error("invalid_args", "nonce/cloudProjectNumber fehlt oder ist ungültig", null)
                return@setMethodCallHandler
            }

            val integrityManager = IntegrityManagerFactory.create(applicationContext)
            val request = IntegrityTokenRequest.builder()
                .setNonce(nonce)
                .setCloudProjectNumber(cloudProjectNumber)
                .build()

            integrityManager.requestIntegrityToken(request)
                .addOnSuccessListener { response -> result.success(response.token()) }
                .addOnFailureListener { error -> result.error("integrity_failed", error.message, null) }
        }
    }

    /**
     * Bridges NotificationHubService (Dart, see notification_hub_service.dart)
     * to NotificationListenerBridgeService's native SharedPreferences file
     * (Runde 14, Einheiten 6+8) — "Benachrichtigungszugriff" is a special OS
     * permission the user grants manually in system settings
     * (Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS), not a normal
     * permission_handler runtime dialog, so there is no "request" call here,
     * only a way to open that settings screen and read back its state.
     */
    private fun configureNotificationHubChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationHubChannelName).setMethodCallHandler { call, result ->
            val prefs = applicationContext.getSharedPreferences(
                NotificationListenerBridgeService.PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            when (call.method) {
                "isListenerEnabled" -> {
                    val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(applicationContext)
                    result.success(enabledPackages.contains(applicationContext.packageName))
                }
                "openListenerSettings" -> {
                    startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(null)
                }
                "setCaptureEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    prefs.edit().putBoolean(NotificationListenerBridgeService.KEY_CAPTURE_ENABLED, enabled).apply()
                    result.success(null)
                }
                "getCaptured" -> {
                    result.success(prefs.getString(NotificationListenerBridgeService.KEY_CAPTURED_JSON, "[]"))
                }
                "clearCaptured" -> {
                    prefs.edit().remove(NotificationListenerBridgeService.KEY_CAPTURED_JSON).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
