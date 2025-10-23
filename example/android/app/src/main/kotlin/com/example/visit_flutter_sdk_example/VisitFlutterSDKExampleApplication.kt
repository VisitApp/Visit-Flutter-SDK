package com.example.visit_flutter_sdk_example

import android.app.Application
import com.example.visit_flutter_sdk.TimberUtils

class VisitFlutterSDKExampleApplication: Application() {
    override fun onCreate() {
        super.onCreate()
        TimberUtils.configTimber(this)
    }
}