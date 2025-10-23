package com.example.visit_flutter_sdk

import android.content.Context
import android.content.pm.ApplicationInfo
import io.flutter.BuildConfig
import timber.log.Timber

object TimberUtils {

    @JvmStatic
    fun configTimber(context: Context? = null) {
        val isDebug = BuildConfig.DEBUG || isAppDebuggable(context)
        if (isDebug) {
            Timber.plant(Timber.DebugTree())
        }
    }

    private fun isAppDebuggable(context: Context?): Boolean {
        if (context == null) return false
        return (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }
}

