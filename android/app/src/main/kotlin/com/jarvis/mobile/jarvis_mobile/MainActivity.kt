package com.jarvis.mobile.jarvis_mobile

import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
class MainActivity : FlutterActivity() {
    private val channelName = "com.jarvis.mobile.jarvis_mobile/integrity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
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
}
