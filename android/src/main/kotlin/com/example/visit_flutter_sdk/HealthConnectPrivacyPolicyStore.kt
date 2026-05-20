package com.example.visit_flutter_sdk

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

object HealthConnectPrivacyPolicyStore {
    const val META_DATA_KEY = "visit_flutter_sdk.health_connect_privacy_policy_url"

    fun resolve(context: Context): String? {
        return normalizeUrl(readManifestUrl(context))
    }

    private fun readManifestUrl(context: Context): String? {
        val appInfo: ApplicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA
            )
        }

        return appInfo.metaData?.getString(META_DATA_KEY)
    }

    private fun normalizeUrl(url: String?): String? {
        val trimmedUrl = url?.trim()
        if (trimmedUrl.isNullOrEmpty()) {
            return null
        }

        val uri = Uri.parse(trimmedUrl)
        val scheme = uri.scheme?.lowercase()
        if ((scheme == "https" || scheme == "http") && !uri.host.isNullOrBlank()) {
            return trimmedUrl
        }

        return null
    }
}
