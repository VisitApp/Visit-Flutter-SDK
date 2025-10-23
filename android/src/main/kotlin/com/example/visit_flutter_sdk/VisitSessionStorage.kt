package com.example.visit_flutter_sdk

import android.content.Context
import android.content.SharedPreferences

class VisitSessionStorage(context: Context) {

  private val BASE_URL = "baseURL"
  private val DAILY_LAST_SYNC = "dailyLastSync"
  private val HOURLY_LAST_SYNC = "hourlyLastSync"
  private val VISIT_AUTH_TOKEN = "visitAuthToken"

  private val sharedPreferences: SharedPreferences =
    context.getSharedPreferences("VisitSharedPref", Context.MODE_PRIVATE)

  fun saveBaseUrl(value: String) {
    sharedPreferences.edit().putString(BASE_URL, value).apply()
  }

  fun getBaseURL(): String? {
    return sharedPreferences.getString(BASE_URL, null)
  }


  fun saveDailyLastSyncTimeStamp(value: Long) {
    sharedPreferences.edit().putLong(DAILY_LAST_SYNC, value).apply()
  }


  fun getDailyLastSyncTimestamp(): Long {
    return sharedPreferences.getLong(DAILY_LAST_SYNC, -1L)
  }

  fun saveHourlyLastSyncTimeStamp(value: Long) {
    sharedPreferences.edit().putLong(HOURLY_LAST_SYNC, value).apply()
  }


  fun getHourlyLastSyncTimeStamp(): Long {
    return sharedPreferences.getLong(HOURLY_LAST_SYNC, -1L)
  }

  fun saveVisitAuthToken(value: String) {
    sharedPreferences.edit().putString(VISIT_AUTH_TOKEN, value).apply()
  }

  fun getVisitAuthToken(): String? {
    return sharedPreferences.getString(VISIT_AUTH_TOKEN, null)
  }
}
