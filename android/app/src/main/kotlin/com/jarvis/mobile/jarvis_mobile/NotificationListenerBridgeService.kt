package com.jarvis.mobile.jarvis_mobile

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

/**
 * Captures other apps' notification previews (package/title/text/postedAt)
 * once the user has granted "Benachrichtigungszugriff"
 * (Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS — a special, manually
 * granted OS permission, not a normal runtime dialog) AND turned on the
 * "Benachrichtigungen erfassen" toggle in Einstellungen (see
 * NotificationHubService/MainActivity's notification_hub MethodChannel,
 * which reads/writes the same SharedPreferences file this service uses).
 * Granting the OS-level access alone does not start capturing.
 *
 * Writes into its OWN native SharedPreferences file rather than Flutter's
 * shared_preferences storage format, so this doesn't depend on that
 * plugin's private on-disk layout.
 */
class NotificationListenerBridgeService : NotificationListenerService() {
    companion object {
        const val PREFS_NAME = "jarvis_notification_hub"
        const val KEY_CAPTURE_ENABLED = "capture_enabled"
        const val KEY_CAPTURED_JSON = "captured_json"

        // Oldest entries are dropped once this many are stored — same
        // capped-list convention as LogService's maxEntries.
        const val MAX_CAPTURED = 200
    }

    private fun prefs(): SharedPreferences =
        applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val prefs = prefs()
        if (!prefs.getBoolean(KEY_CAPTURE_ENABLED, false)) return

        // Never capture this app's own notifications (timers/briefings/
        // alerts) — nothing useful to summarize there.
        if (sbn.packageName == applicationContext.packageName) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        val entry = JSONObject()
        entry.put("packageName", sbn.packageName)
        entry.put("title", title)
        entry.put("text", text)
        entry.put("postedAt", sbn.postTime)

        val existing = try {
            JSONArray(prefs.getString(KEY_CAPTURED_JSON, "[]"))
        } catch (e: Exception) {
            JSONArray()
        }

        val updated = JSONArray()
        val start = maxOf(0, existing.length() - (MAX_CAPTURED - 1))
        for (i in start until existing.length()) {
            updated.put(existing.get(i))
        }
        updated.put(entry)

        prefs.edit().putString(KEY_CAPTURED_JSON, updated.toString()).apply()
    }
}
