package com.example.visit_flutter_sdk

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.core.content.FileProvider
import androidx.health.connect.client.PermissionController
import com.getvisitapp.google_fit.HealthConnectListener
import com.getvisitapp.google_fit.data.VisitStepSyncHelper
import com.getvisitapp.google_fit.healthConnect.activity.HealthConnectUtil
import com.getvisitapp.google_fit.healthConnect.contants.Contants.previouslyRevoked
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.cancel
import kotlinx.coroutines.suspendCancellableCoroutine
import timber.log.Timber

/** Each activity attachment owns its requests and permission launcher. */
class VisitFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    val TAG = "mytag"
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var mainActivity: Activity? = null
    private var requestScope: CoroutineScope? = null
    private var pendingPermission: Deferred<Boolean>? = null
    private var attachmentGeneration = 0L
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null
    private var visitStepSyncHelper: VisitStepSyncHelper? = null
    private var healthConnectUtil: HealthConnectUtil? = null
    private var syncDataWithServer = false
    private var isLoggingEnabled = true
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    private val healthConnectListener = object : HealthConnectListener {
        // Data and permissions are completed by their owning coroutine, never by this listener.
        override fun loadVisitWebViewGraphData(webString: String) = Unit
        override fun userAcceptedHealthConnectPermission() = Unit
        override fun userDeniedHealthConnectPermission() = Unit
        override fun requestPermission() = Unit
        override fun updateHealthConnectConnectionStatus(status: HealthConnectConnectionState, text: String) = Unit
        override fun logHealthConnectError(throwable: Throwable) {
            Timber.tag(TAG).e(throwable, "Health Connect initialization failed")
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "visit_flutter_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachActivity()
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attachActivity(binding)
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attachActivity(binding)
    override fun onDetachedFromActivity() = detachActivity()
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()

    private fun attachActivity(binding: ActivityPluginBinding) {
        detachActivity()
        mainActivity = binding.activity
        val util = HealthConnectUtil(binding.activity, healthConnectListener)
        healthConnectUtil = util
        visitStepSyncHelper = VisitStepSyncHelper(binding.activity)
        requestScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        util.initialize()
    }

    private fun detachActivity() {
        attachmentGeneration++
        healthConnectUtil?.cancelPendingGraphRequests()
        requestScope?.cancel()
        requestScope = null
        pendingPermission = null
        permissionLauncher?.unregister()
        permissionLauncher = null
        healthConnectUtil?.scope?.cancel()
        healthConnectUtil = null
        visitStepSyncHelper = null
        mainActivity = null
    }

    private suspend fun requestFitnessPermission(util: HealthConnectUtil): Boolean {
        val activity = mainActivity as? ComponentActivity
            ?: throw HealthRequestException("activity_unavailable", "A ComponentActivity is required for Health Connect permissions.")
        val generation = attachmentGeneration
        return suspendCancellableCoroutine { continuation ->
            val completed = AtomicBoolean(false)
            lateinit var launcher: ActivityResultLauncher<Set<String>>
            fun unregister() {
                launcher.unregister()
                if (permissionLauncher === launcher) permissionLauncher = null
            }
            launcher = activity.activityResultRegistry.register(
                "visit_flutter_sdk.health_permission.${UUID.randomUUID()}",
                PermissionController.createRequestPermissionResultContract(),
            ) { granted ->
                if (generation == attachmentGeneration && completed.compareAndSet(false, true)) {
                    unregister()
                    val accepted = granted.containsAll(util.PERMISSIONS)
                    if (accepted) previouslyRevoked = false
                    continuation.resume(accepted)
                }
            }
            permissionLauncher = launcher
            continuation.invokeOnCancellation {
                if (completed.compareAndSet(false, true)) mainHandler.post { unregister() }
            }
            try {
                launcher.launch(util.PERMISSIONS)
            } catch (error: Exception) {
                if (completed.compareAndSet(false, true)) {
                    unregister()
                    continuation.resumeWithException(error)
                }
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
                "shareFile" -> shareFile(call, result)
                "getHealthConnectStatus" -> healthRequest(result) { status(it).name }
                "askForFitnessPermission" -> healthRequest(result) {
                    if (ensurePermission(it)) "GRANTED" else "CANCELLED"
                }
                "requestDailyFitnessData" -> healthRequest(result) {
                    requirePermission(it)
                    it.getDashboardData()
                }
                "requestActivityDataFromHealthConnect" -> {
                    val type = requireNotNull(call.argument<String>("type")) { "Missing graph type." }
                    val frequency = requireNotNull(call.argument<String>("frequency")) { "Missing graph frequency." }
                    val timestamp = requireNotNull(integerArgument(call.argument<Any>("timestamp"))) { "Expected integer timestamp." }
                    healthRequest(result) {
                        requirePermission(it)
                        it.getGraphData(type, frequency, timestamp)
                    }
                }
                "openHealthConnectApp" -> {
                    val util = healthConnectUtil
                        ?: throw HealthRequestException("activity_unavailable", "No activity is attached.")
                    util.openHealthConnectApp()
                    result.success(null)
                }
                "updateApiBaseUrl" -> updateApiBaseUrl(call, result)
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            replyError(result, error)
        }
    }

    // Each invocation captures its own Result. SDK suspend functions return once;
    // no listener can complete a method-channel reply or replace another caller.
    private fun healthRequest(result: Result, read: suspend (HealthConnectUtil) -> Any?) {
        val util = healthConnectUtil
        val scope = requestScope
        if (util == null || scope == null) {
            result.error("activity_unavailable", "No activity is attached.", null)
            return
        }
        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val response = runCatching { read(util) }
            response.fold(result::success) { replyError(result, it) }
        }
    }

    private fun replyError(result: Result, error: Throwable) {
        when (error) {
            is HealthRequestException -> result.error(error.code, error.message, error.details)
            is TimeoutCancellationException -> result.error("health_connect_timeout", "Health Connect timed out.", null)
            is CancellationException -> result.error("activity_detached", "The activity was detached.", null)
            is IllegalArgumentException -> result.error("invalid_arguments", error.message, null)
            else -> result.error("health_connect_error", "Unable to complete the native request.", null)
        }
    }

    private suspend fun status(util: HealthConnectUtil): HealthConnectConnectionState =
        withTimeout(30_000) { withContext(Dispatchers.IO) { util.checkAvailability() } }

    private suspend fun requirePermission(util: HealthConnectUtil) {
        if (!ensurePermission(util)) {
            throw HealthRequestException("permission_denied", "Health Connect permission was denied.")
        }
    }

    private suspend fun ensurePermission(util: HealthConnectUtil): Boolean {
        pendingPermission?.takeUnless { it.isCompleted }?.let { return it.await() }
        val scope = requestScope
            ?: throw HealthRequestException("activity_detached", "The activity was detached.")
        val flight = scope.async(start = CoroutineStart.LAZY) {
            when (val state = status(util)) {
                HealthConnectConnectionState.CONNECTED -> true
                HealthConnectConnectionState.INSTALLED ->
                    requestFitnessPermission(util) && status(util) == HealthConnectConnectionState.CONNECTED
                else -> throw HealthRequestException("health_connect_unavailable", "Health Connect is unavailable.", state.name)
            }
        }
        pendingPermission = flight
        flight.invokeOnCompletion { if (pendingPermission === flight) pendingPermission = null }
        flight.start()
        return flight.await()
    }

    private class HealthRequestException(val code: String, message: String, val details: Any? = null) : Exception(message)

    private fun integerArgument(value: Any?): Long? = when (value) {
        is Int -> value.toLong()
        is Long -> value
        else -> null
    }

    private fun updateApiBaseUrl(
        call: MethodCall,
        promise: Result
    ) {
        val apiBaseUrl: String = call.argument<String>("apiBaseUrl")!!
        val authToken: String = call.argument<String>("authtoken")!!
        val googleFitLastSync: Long = integerArgument(call.argument<Any>("googleFitLastSync"))
            ?: throw HealthRequestException("invalid_arguments", "Expected integer googleFitLastSync.")
        val gfHourlyLastSync: Long = integerArgument(call.argument<Any>("gfHourlyLastSync"))
            ?: throw HealthRequestException("invalid_arguments", "Expected integer gfHourlyLastSync.")



        if (isLoggingEnabled) {
            Log.d(
                "mytag",
                "GoogleFitPermissionModule syncDataWithServer(): baseUrl: " + apiBaseUrl + " authToken: " + authToken + " googleFitLastSync: " + googleFitLastSync + "  gfHourlyLastSync:" + gfHourlyLastSync
            )
        }

        if (!syncDataWithServer && healthConnectUtil != null) {
            Timber.d("mytag: syncDataWithServer() called")
            visitStepSyncHelper?.sendDataToVisitServer(
                healthConnectUtil!!,
                googleFitLastSync,
                gfHourlyLastSync,
                "$apiBaseUrl/",
                authToken
            )
            syncDataWithServer = true
            promise.success("Health Data Sync Started")
        } else {
            promise.success("Health Data Already Synced")
        }

    }


    private fun shareFile(call: MethodCall, result: Result) {
        val filePath = call.argument<String>("path")
        if (filePath.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing file path.", null)
            return
        }

        val file = File(filePath)
        if (!file.exists()) {
            result.error("file_not_found", "File does not exist.", filePath)
            return
        }

        val context = mainActivity ?: appContext

        val uri = try {
            getFileUri(context, file)
        } catch (error: Exception) {
            result.error("file_uri_failed", error.localizedMessage, null)
            return
        }

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = call.argument<String>("mimeType") ?: "*/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(context.contentResolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooserIntent = Intent.createChooser(shareIntent, null)
        if (mainActivity == null) {
            chooserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            context.startActivity(chooserIntent)
            result.success(null)
        } catch (error: Exception) {
            result.error("share_failed", error.localizedMessage, null)
        }
    }

    private fun getFileUri(context: Context, file: File) = try {
        createFileUri(context, file)
    } catch (error: IllegalArgumentException) {
        val shareDirectory = File(context.cacheDir, "visit_flutter_sdk_shared")
        shareDirectory.mkdirs()
        val shareFile = File(shareDirectory, file.name)
        file.copyTo(shareFile, overwrite = true)
        createFileUri(context, shareFile)
    }

    private fun createFileUri(context: Context, file: File) =
        FileProvider.getUriForFile(
            context,
            "${context.packageName}.visit_flutter_sdk.fileprovider",
            file
        )
}
