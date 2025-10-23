package com.example.visit_flutter_sdk

import android.os.Bundle
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.RelativeLayout
import androidx.appcompat.app.AppCompatActivity

class HealthConnectPermissionUsageActivity : AppCompatActivity() {
//
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_connect_permission_usage)

        val relativeLayout = RelativeLayout(this)
        val lp = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT
        )
        relativeLayout.layoutParams = lp

        val mWebView = WebView(this)
        mWebView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )

        relativeLayout.addView(mWebView)

        setContentView(relativeLayout)
        mWebView.settings.javaScriptEnabled = true

        mWebView.loadUrl("https://www.google.com")
    }
}