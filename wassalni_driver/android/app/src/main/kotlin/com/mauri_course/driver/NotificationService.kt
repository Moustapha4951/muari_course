package com.mauri_course.driver

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import android.app.PendingIntent
import android.app.NotificationManager
import android.app.NotificationChannel
import android.os.Build
import androidx.core.app.NotificationCompat

class NotificationService : Service() {
    private val TAG = "NotificationService"
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started")
        
        val rideId = intent?.getStringExtra("RIDE_ID")
        val pickupAddress = intent?.getStringExtra("PICKUP_ADDRESS") ?: "موقع غير معروف"
        
        if (rideId != null) {
            // Create notification channel for Android O+
            createNotificationChannel()
            
            // Create and show notification
            showNotification(rideId, pickupAddress)
        }
        
        return START_NOT_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "rides_channel",
                "رحلات جديدة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات الرحلات الجديدة"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 1000, 500, 1000)
                enableLights(true)
                lightColor = android.graphics.Color.GREEN
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification(rideId: String, pickupAddress: String) {
        // Create intent to open the app when notification is clicked
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "OPEN_RIDE_ACTION"
            putExtra("RIDE_ID", rideId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                     Intent.FLAG_ACTIVITY_CLEAR_TOP or
                     Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, "rides_channel")
            .setContentTitle("رحلة جديدة متاحة!")
            .setContentText("رحلة جديدة من $pickupAddress")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(pendingIntent, true)
            .setOngoing(true)
            .build()
            
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(rideId.hashCode(), notification)
        
        // Also try to launch the app directly
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error launching app directly: ${e.message}")
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}
