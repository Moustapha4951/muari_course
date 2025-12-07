package com.mauri_course.driver

import android.app.Activity
import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    companion object {
        private var instance: MainActivity? = null
        private const val REQUEST_CODE_BATTERY_OPTIMIZATION = 1001
        private const val TAG = "MainActivity"

        @JvmStatic
        fun getInstance(): MainActivity? {
            return instance
        }
    }

    private val CHANNEL = "com.mauri_course.driver/app_launcher"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "launchApp" -> {
                            val rideId = call.argument<String>("rideId") ?: ""
                            val pickupAddress = call.argument<String>("pickupAddress") ?: ""
                            Log.d(TAG, "Received launchApp request with rideId: $rideId")
                            
                            try {
                                // Schedule app launch using RideNotificationHelper
                                com.mauri_course.driver.RideNotificationHelper.scheduleAppLaunch(this, rideId)
                                
                                // Also send broadcast to NotificationReceiver
                                val broadcastIntent = Intent("com.mauri_course.driver.OPEN_APP").apply {
                                    putExtra("rideId", rideId)
                                    putExtra("pickupAddress", pickupAddress)
                                }
                                sendBroadcast(broadcastIntent)
                                
                                // Direct app launch attempt
                                openAppDirectly(rideId)
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error in launchApp: ${e.message}")
                                result.error("LAUNCH_ERROR", e.message, null)
                            }
                        }
                        "checkBatteryOptimization" -> {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                                    if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                                        intent.data = Uri.parse("package:$packageName")
                                        startActivityForResult(intent, REQUEST_CODE_BATTERY_OPTIMIZATION)
                                    }
                                }
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error in checkBatteryOptimization: ${e.message}")
                                result.error("BATTERY_ERROR", e.message, null)
                            }
                        }
                        "getPendingRideId" -> {
                            try {
                                val prefs = getSharedPreferences("ride_prefs", Context.MODE_PRIVATE)
                                val rideId = prefs.getString("pending_ride_id", "") ?: ""
                                result.success(rideId)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error in getPendingRideId: ${e.message}")
                                result.error("PREF_ERROR", e.message, null)
                            }
                        }
                        "showNotification" -> {
                            try {
                                val rideId = call.argument<String>("rideId") ?: ""
                                val pickupAddress = call.argument<String>("pickupAddress") ?: ""
                                
                                // Start NotificationService to show notification
                                val serviceIntent = Intent(this, NotificationService::class.java).apply {
                                    putExtra("RIDE_ID", rideId)
                                    putExtra("PICKUP_ADDRESS", pickupAddress)
                                }
                                
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                    startForegroundService(serviceIntent)
                                } else {
                                    startService(serviceIntent)
                                }
                                
                                result.success(true)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error in showNotification: ${e.message}")
                                result.error("NOTIFICATION_ERROR", e.message, null)
                            }
                        }
                        else -> {
                            result.notImplemented()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "General error in method channel: ${e.message}")
                    result.error("GENERAL_ERROR", e.message, null)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in configureFlutterEngine: ${e.message}")
        }
    }
    
    private fun openAppDirectly(rideId: String) {
        try {
            // استخدام intent.packageName لإعادة تشغيل التطبيق نفسه
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            launchIntent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                          Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                          Intent.FLAG_ACTIVITY_SINGLE_TOP)
                it.action = "OPEN_RIDE_ACTION"
                it.putExtra("RIDE_ID", rideId)
                startActivity(it)
                Log.d(TAG, "Launch intent sent")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app", e)
        }
    }

    private fun wakeDeviceAndScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = pm.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE, "WassalniDriver:WakeLock")
            wakeLock.acquire(10*1000L) // 10 ثوانٍ كافية
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            }
            
            wakeLock.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock: ${e.message}")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            super.onCreate(savedInstanceState)
            instance = this
            Log.d(TAG, "MainActivity onCreate started")
            
            handleIntent(intent)
            
            // طلب تجاهل تحسينات البطارية (سيساعد في استلام الإشعارات والبقاء في الخلفية)
            requestIgnoreBatteryOptimizations()
            
            Log.d(TAG, "MainActivity onCreate completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onCreate: ${e.message}")
        }
    }
    
    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to request battery optimization exception", e)
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        try {
            if (intent?.action == "OPEN_RIDE_ACTION") {
                val rideId = intent.getStringExtra("RIDE_ID")
                Log.d(TAG, "Received ride ID from intent: $rideId")
                
                // يمكن حفظ هذا إلى الـ SharedPrefs للاستخدام من Flutter
                if (rideId != null) {
                    val prefs = getSharedPreferences("ride_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("pending_ride_id", rideId).apply()
                    Log.d(TAG, "Saved ride ID to SharedPreferences: $rideId")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in handleIntent: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance === this) {
            instance = null
        }
    }
}
