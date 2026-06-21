package com.sajnire.app

import android.app.Activity
import android.content.Intent
import android.content.IntentSender
import com.google.android.gms.auth.api.identity.GetPhoneNumberHintIntentRequest
import com.google.android.gms.auth.api.identity.Identity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.sajnire.app/auth"
    private val REQUEST_PHONE_HINT = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestPhoneHint") {
                // Return immediately if there is already a pending request
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "A phone hint request is already active", null)
                    return@setMethodCallHandler
                }
                
                pendingResult = result
                val request = GetPhoneNumberHintIntentRequest.builder().build()
                
                Identity.getSignInClient(this)
                    .getPhoneNumberHintIntent(request)
                    .addOnSuccessListener { pendingIntentResponse ->
                        try {
                            startIntentSenderForResult(
                                pendingIntentResponse.intentSender,
                                REQUEST_PHONE_HINT,
                                null, 0, 0, 0
                            )
                        } catch (e: IntentSender.SendIntentException) {
                            pendingResult?.error("HINT_FAILED", "Failed to start intent sender: ${e.message}", null)
                            pendingResult = null
                        }
                    }
                    .addOnFailureListener { e ->
                        pendingResult?.error("HINT_UNAVAILABLE", "Phone hint not available: ${e.message}", null)
                        pendingResult = null
                    }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_PHONE_HINT) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                try {
                    val phoneNumber = Identity.getSignInClient(this).getPhoneNumberFromIntent(data)
                    pendingResult?.success(phoneNumber)
                } catch (e: Exception) {
                    pendingResult?.error("EXTRACT_FAILED", e.message, null)
                }
            } else {
                pendingResult?.error("CANCELLED", "User cancelled or failed", null)
            }
            pendingResult = null
        }
    }
}
