package com.youkdonghun.sprache

import android.accounts.Account
import android.app.Activity
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.Scopes
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingResult: MethodChannel.Result? = null

    private val authorizationLauncher =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { activityResult ->
            val result = pendingResult ?: return@registerForActivityResult
            pendingResult = null

            if (activityResult.resultCode != Activity.RESULT_OK) {
                result.error("picker_cancelled", "Google Drive folder selection was cancelled", null)
                return@registerForActivityResult
            }

            try {
                val authorizationResult =
                    Identity.getAuthorizationClient(this)
                        .getAuthorizationResultFromIntent(activityResult.data)
                completeAuthorization(authorizationResult, result)
            } catch (exception: ApiException) {
                result.error(
                    "authorization_failed",
                    exception.localizedMessage ?: "Google Drive authorization failed",
                    exception.statusCode,
                )
            }
        }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GOOGLE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authorizeDrivePicker" -> {
                    val email = call.argument<String>("email")
                    if (email.isNullOrBlank()) {
                        result.error("missing_account", "A Google account email is required", null)
                    } else {
                        authorizeDrivePicker(email, result)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun authorizeDrivePicker(email: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("authorization_in_progress", "Google authorization is already in progress", null)
            return
        }

        val request =
            AuthorizationRequest.builder()
                .setAccount(Account(email, GOOGLE_ACCOUNT_TYPE))
                .setRequestedScopes(listOf(Scope(Scopes.DRIVE_FILE)))
                .setOptOutIncludingGrantedScopes(true)
                .setPrompt(AuthorizationRequest.Prompt.CONSENT)
                .addResourceParameter(
                    AuthorizationRequest.ResourceParameter.PICKER_OAUTH_TRIGGER,
                    "true",
                )
                .addResourceParameter(
                    AuthorizationRequest.ResourceParameter.PICKER_ALLOW_FOLDER_SELECTION,
                    "true",
                )
                .addResourceParameter(
                    AuthorizationRequest.ResourceParameter.PICKER_MIMETYPES,
                    DRIVE_FOLDER_MIME_TYPE,
                )
                .build()

        Identity.getAuthorizationClient(this)
            .authorize(request)
            .addOnSuccessListener { authorizationResult ->
                if (authorizationResult.hasResolution()) {
                    val pendingIntent = authorizationResult.pendingIntent
                    if (pendingIntent == null) {
                        result.error(
                            "missing_resolution",
                            "Google authorization did not provide a resolution",
                            null,
                        )
                        return@addOnSuccessListener
                    }
                    pendingResult = result
                    authorizationLauncher.launch(
                        IntentSenderRequest.Builder(pendingIntent.intentSender).build(),
                    )
                } else {
                    completeAuthorization(authorizationResult, result)
                }
            }
            .addOnFailureListener { exception ->
                result.error(
                    "authorization_failed",
                    exception.localizedMessage ?: "Google Drive authorization failed",
                    null,
                )
            }
    }

    private fun completeAuthorization(
        authorizationResult: AuthorizationResult,
        result: MethodChannel.Result,
    ) {
        val accessToken = authorizationResult.accessToken
        val pickedIds =
            authorizationResult.tokenResponseParams
                ?.getString(PICKED_FILE_IDS)
                ?.split(",")
                ?.map(String::trim)
                ?.filter(String::isNotEmpty)
                .orEmpty()

        if (accessToken.isNullOrBlank()) {
            result.error("missing_access_token", "Google did not return an access token", null)
            return
        }
        if (pickedIds.isEmpty()) {
            result.error("missing_folder", "Google Picker did not return a folder", null)
            return
        }

        result.success(
            mapOf(
                "accessToken" to accessToken,
                "folderId" to pickedIds.first(),
            ),
        )
    }

    companion object {
        private const val GOOGLE_CHANNEL = "com.youkdonghun.sprache/google"
        private const val GOOGLE_ACCOUNT_TYPE = "com.google"
        private const val DRIVE_FOLDER_MIME_TYPE = "application/vnd.google-apps.folder"
        private const val PICKED_FILE_IDS = "picked_file_ids"
    }
}
