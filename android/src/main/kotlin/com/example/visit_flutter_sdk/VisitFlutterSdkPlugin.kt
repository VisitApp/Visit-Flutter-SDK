package com.example.visit_flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.os.Handler
import android.os.Looper
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.PermissionController
import com.getvisitapp.google_fit.HealthConnectListener
import com.getvisitapp.google_fit.data.VisitStepSyncHelper
import com.getvisitapp.google_fit.healthConnect.activity.HealthConnectUtil
import com.getvisitapp.google_fit.healthConnect.contants.Contants.previouslyRevoked
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState.CONNECTED
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState.INSTALLED
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState.NONE
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState.NOT_INSTALLED
import com.getvisitapp.google_fit.healthConnect.enums.HealthConnectConnectionState.NOT_SUPPORTED
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.lang.reflect.Method

/** VisitFlutterSdkPlugin */
class VisitFlutterSdkPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    ActivityResultListener {

    val TAG = "mytag"

    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var mainActivity: Activity? = null


    private var promise: Result? = null
    private var healthConnectStatusPromise: Result? = null
    private var dataRetrivalPromise: Result? = null

    private var isLoggingEnabled =
        true //Todo: figure out to make it configurable dynamically, that i can pass as parameter.

    private var visitStepSyncHelper: VisitStepSyncHelper? = null
    private var healthConnectUtil: HealthConnectUtil? = null
    private var syncDataWithServer = false

    private lateinit var visitSessionStorage: VisitSessionStorage

    lateinit var requestPermissions: ActivityResultLauncher<Set<String>>


    private val healthConnectListener = object : HealthConnectListener {
        override fun loadVisitWebViewGraphData(webString: String) {
            Timber.tag(TAG).d("webString: $webString")

            Handler(Looper.getMainLooper()).post {
                if (isLoggingEnabled) {
                    Timber.tag(TAG).d("mytag: loadVisitWebViewGraphData: $webString")
                }
                dataRetrivalPromise?.success(webString)
            }
        }

        override fun logHealthConnectError(throwable: Throwable) {
            throwable.printStackTrace()
        }

        override fun requestPermission() {
            Timber.tag(TAG).d("requestPermission called 218")
            requestPermissions.launch(healthConnectUtil!!.PERMISSIONS)
        }

        override fun updateHealthConnectConnectionStatus(
            healthConnectConnectionState: HealthConnectConnectionState, s: String
        ) {
            Timber.tag(TAG)
                .d("updateHealthConnectConnectionStatus: %s", healthConnectConnectionState)
            when (healthConnectConnectionState) {
                CONNECTED -> {}
                NOT_SUPPORTED -> {}
                NOT_INSTALLED -> {}
                INSTALLED -> {}
                NONE -> {}
            }
        }

        override fun userAcceptedHealthConnectPermission() {
            Timber.tag(TAG).d("userAcceptedHealthConnectPermission")
            promise?.success("GRANTED")
        }

        override fun userDeniedHealthConnectPermission() {
            Timber.tag(TAG).d("userDeniedHealthConnectPermission")
            promise?.success(
                "CANCELLED"
            )
        }
    }


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Timber.tag(TAG).d("onAttachedToEngine() called")
        appContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "visit_flutter_sdk")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        Timber.tag(TAG).d("onDetachedFromEngine() called")
        channel.setMethodCallHandler(null)
    }

    // ActivityAware hooks
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Timber.tag(TAG).d("onAttachedToActivity() called")

        mainActivity = binding.activity
        binding.addActivityResultListener(this)

        val requestPermissionActivityContract =
            PermissionController.createRequestPermissionResultContract()

        //don't initialise the native module if the mainActivity instance is null.
        if (mainActivity == null) {
            return
        }
        visitStepSyncHelper = VisitStepSyncHelper(mainActivity!!)
        healthConnectUtil = HealthConnectUtil(mainActivity!!, healthConnectListener)
        healthConnectUtil!!.initialize()
        visitSessionStorage = VisitSessionStorage(mainActivity!!)


        requestPermissions = (mainActivity as ComponentActivity).registerForActivityResult(
            requestPermissionActivityContract
        ) { granted: Set<String>? ->
            Timber.tag(TAG).d("requestPermissions registerForActivityResult: %s", granted)
            Timber.tag(TAG).d("onActivityResultImplementation execute: result: %s", granted)

            granted?.let {
                if (granted.containsAll(healthConnectUtil!!.PERMISSIONS)) {
                    previouslyRevoked = false


                    Timber.tag(TAG).d("Permissions successfully granted")
                    healthConnectUtil!!.checkPermissionsAndRunForStar(true)
                } else {
                    Timber.tag(TAG).d("Lack of required permissions")
                    healthConnectUtil!!.checkPermissionsAndRunForStar(true)
                }

            }
        }

    }

    override fun onDetachedFromActivity() {
        Timber.tag(TAG).d("onDetachedFromActivity() called")

        mainActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Timber.tag(TAG).d("onReattachedToActivityForConfigChanges() called")

        mainActivity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Timber.tag(TAG).d("onDetachedFromActivityForConfigChanges() called")

        mainActivity = null
    }


    override fun onMethodCall(call: MethodCall, result: Result) {
        call.arguments
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else if (call.method == "getBatteryLevel") {
            val batteryLevel = getBatteryLevel()

            if (batteryLevel != -1) {
                result.success(batteryLevel)
            } else {
                result.error("UNAVAILABLE", "Battery level not available.", null)
            }
        } else if (call.method == "getHealthConnectStatus") {
            getHealthConnectStatus(result)
        } else if (call.method == "askForFitnessPermission") {
            askForFitnessPermission(result)
        } else if (call.method == "requestDailyFitnessData") {
            requestDailyFitnessData(result)
        } else if (call.method == "openHealthConnectApp") {
            openHealthConnectApp(result)
        } else if (call.method == "requestActivityDataFromHealthConnect") {
            requestActivityDataFromHealthConnect(call, result)
        } else {
            result.notImplemented()
        }
    }


    fun getHealthConnectStatus(healthConnectStatusPromise: Result) {
        this.healthConnectStatusPromise = healthConnectStatusPromise

        Timber.tag(TAG).d("mytag: getHealthConnectStatus called")

        healthConnectUtil?.scope?.launch {
            val status: HealthConnectConnectionState = healthConnectUtil!!.checkAvailability()

            withContext(Dispatchers.Main) {
                when (status) {
                    NOT_SUPPORTED -> {
                        healthConnectStatusPromise.success("NOT_SUPPORTED")
                    }

                    NOT_INSTALLED -> {
                        healthConnectStatusPromise.success("NOT_INSTALLED")
                    }

                    INSTALLED -> {
                        healthConnectStatusPromise.success("INSTALLED")
                    }

                    CONNECTED -> {
                        healthConnectStatusPromise.success("CONNECTED")
                    }

                    NONE -> {
                        healthConnectStatusPromise.success("NONE")
                    }
                }
            }
        }
    }


    fun requestDailyFitnessData(promise: Result) {
        this.dataRetrivalPromise = promise

        if (healthConnectUtil!!.healthConnectConnectionState == CONNECTED) {
            healthConnectUtil!!.getVisitDashboardGraph()
        }
    }


    fun askForFitnessPermission(promise: Result) {
        this.promise = promise
        healthConnectUtil?.let {
            if (healthConnectUtil!!.healthConnectConnectionState == CONNECTED) {
                Timber.tag(TAG).d("askForFitnessPermission: already granted")
                promise.success("GRANTED")
            } else {
                Timber.tag(TAG).d("askForFitnessPermission: request permission")
                healthConnectUtil!!.requestPermission()
            }
        }

    }

    fun openHealthConnectApp(promise: Result?) {
        this.promise = promise
        healthConnectUtil?.openHealthConnectApp();
    }

    fun requestActivityDataFromHealthConnect(
        call: MethodCall, promise: Result
    ) {

        // Retrieve arguments safely
        val type: String? = call.argument<String>("type")
        val frequency: String? = call.argument<String>("frequency")
        val timestamp: Long = (call.argument<Number>("timestamp") ?: 0).toLong()



        Timber.tag(TAG).d("Received type=$type, frequency=$frequency, timestamp=$timestamp")

        this.dataRetrivalPromise = promise

        healthConnectUtil?.let {
            if (healthConnectUtil!!.healthConnectConnectionState == HealthConnectConnectionState.CONNECTED) {
                // Example usage
                Timber.tag(TAG).d("requesting data")

                healthConnectUtil!!.getActivityData(type, frequency, timestamp)
            } else {
                Timber.tag(TAG).d("Permission not available, requesting again.")
                healthConnectUtil!!.requestPermission()
            }
        }
    }


    private fun getBatteryLevel(): Int {
        val batteryLevel: Int
        val batteryManager = appContext.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)

        return batteryLevel
    }


    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ): Boolean {
        return false
    }
}
