package com.example.visit_flutter_sdk

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/** VisitFlutterSdkPlugin */
class VisitFlutterSdkPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var applicationContext: Context? = null
  private var activity: Activity? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "visit_flutter_sdk")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
      "shareFile" -> shareFile(call, result)
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    applicationContext = null
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
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

    val context = activity ?: applicationContext
    if (context == null) {
      result.error("no_context", "Unable to open share sheet without a context.", null)
      return
    }

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
    if (activity == null) {
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
