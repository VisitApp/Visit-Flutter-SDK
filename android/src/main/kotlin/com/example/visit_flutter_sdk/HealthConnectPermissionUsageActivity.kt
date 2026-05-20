package com.example.visit_flutter_sdk

import android.os.Bundle
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.RelativeLayout
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat

class HealthConnectPermissionUsageActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val relativeLayout = RelativeLayout(this)
        val lp = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT
        )
        relativeLayout.layoutParams = lp
        val initialPaddingLeft = relativeLayout.paddingLeft
        val initialPaddingTop = relativeLayout.paddingTop
        val initialPaddingRight = relativeLayout.paddingRight
        val initialPaddingBottom = relativeLayout.paddingBottom
        ViewCompat.setOnApplyWindowInsetsListener(relativeLayout) { view, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(
                initialPaddingLeft + systemBars.left,
                initialPaddingTop + systemBars.top,
                initialPaddingRight + systemBars.right,
                initialPaddingBottom + systemBars.bottom
            )
            insets
        }

        val mWebView = WebView(this)
        mWebView.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT
        )

        relativeLayout.addView(mWebView)

        setContentView(relativeLayout)
        mWebView.settings.javaScriptEnabled = true

        val privacyPolicyUrl = HealthConnectPrivacyPolicyStore.resolve(this)
        if (privacyPolicyUrl != null) {
            mWebView.loadUrl(privacyPolicyUrl)
        } else {
            mWebView.loadDataWithBaseURL(
                null,
                missingPrivacyPolicyHtml(),
                "text/html",
                "UTF-8",
                null
            )
        }
    }

    private fun missingPrivacyPolicyHtml(): String {
        return """
            <!doctype html>
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1" />
                <style>
                  body {
                    margin: 0;
                    padding: 24px;
                    font-family: sans-serif;
                    color: #202124;
                    background: #ffffff;
                  }
                  h1 {
                    margin: 0 0 12px;
                    font-size: 20px;
                    line-height: 1.3;
                  }
                  p {
                    margin: 0;
                    font-size: 15px;
                    line-height: 1.5;
                  }
                  code {
                    word-break: break-word;
                  }
                </style>
              </head>
              <body>
                <h1>Privacy policy unavailable</h1>
                <p>
                  Configure a valid Health Connect privacy policy URL using the
                  <code>${HealthConnectPrivacyPolicyStore.META_DATA_KEY}</code>
                  Android manifest metadata entry.
                </p>
              </body>
            </html>
        """.trimIndent()
    }
}
