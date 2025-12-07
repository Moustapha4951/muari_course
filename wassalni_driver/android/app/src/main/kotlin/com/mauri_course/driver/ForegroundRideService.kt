package com.mauri_course.driver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class ForegroundRideService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private val NOTIFICATION_ID = 1234
    private val CHANNEL_ID = "foreground_service_channel"

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Foreground service created")
        createNotificationChannel()
        acquireWakeLock()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Foreground service started")
        
        // اتخاذ قرار بشأن الإجراء المطلوب استنادًا إلى النية
        val action = intent?.action
        
        when (action) {
            "START_FOREGROUND" -> startForegroundService()
            "OPEN_APP" -> {
                val rideId = intent.getStringExtra("RIDE_ID") ?: ""
                openApp(rideId)
            }
            "STOP_SERVICE" -> stopSelf()
        }

        return START_STICKY
    }
    
    private fun openApp(rideId: String) {
        Log.d(TAG, "Attempting to open app with ride ID: $rideId")
        
        // إيقاظ الجهاز
        try {
            wakeLock?.acquire(10*60*1000L)
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring wake lock", e)
        }
        
        // فتح النشاط الرئيسي
        try {
            val launchIntent = Intent(this, com.mauri_course.driver.MainActivity::class.java)
            launchIntent.action = "OPEN_RIDE_ACTION"
            launchIntent.putExtra("RIDE_ID", rideId)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                                Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(launchIntent)
            
            // تحديث الإشعار
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notification = createNotification("جارٍ معالجة رحلة جديدة", "يتم فتح التطبيق للرحلة رقم: $rideId")
            notificationManager.notify(NOTIFICATION_ID, notification)
            
            Log.d(TAG, "App launch intent sent")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening app", e)
        } finally {
            // تحرير قفل الاستيقاظ بعد محاولة فتح التطبيق
            wakeLock?.release()
        }
    }

    private fun startForegroundService() {
        val notification = createNotification("خدمة وصلني تعمل في الخلفية", "تتم مراقبة الرحلات الجديدة")
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotification(title: String, content: String): Notification {
        val notificationIntent = Intent(this, com.mauri_course.driver.MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "خدمة متابعة الرحلات",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "قناة إشعارات لخدمة متابعة الرحلات في الخلفية"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "WassalniDriver:RideServiceWakeLock"
        )
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.release()
        Log.d(TAG, "Foreground service destroyed")
    }

    companion object {
        private const val TAG = "ForegroundRideService"
        
        fun startService(context: Context) {
            val intent = Intent(context, ForegroundRideService::class.java).apply {
                action = "START_FOREGROUND"
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun openApp(context: Context, rideId: String) {
            val intent = Intent(context, ForegroundRideService::class.java).apply {
                action = "OPEN_APP"
                putExtra("RIDE_ID", rideId)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stopService(context: Context) {
            val intent = Intent(context, ForegroundRideService::class.java).apply {
                action = "STOP_SERVICE"
            }
            context.startService(intent)
        }
    }
}
