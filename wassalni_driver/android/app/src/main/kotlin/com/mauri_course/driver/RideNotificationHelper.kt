package com.mauri_course.driver

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log

object RideNotificationHelper {
    private const val TAG = "RideNotificationHelper"
    private const val ALARM_ID = 12345

    fun scheduleAppLaunch(context: Context, rideId: String) {
        try {
            Log.d(TAG, "Scheduling immediate app launch for ride: $rideId")
            
            // حفظ معرف الرحلة
            val prefs = context.getSharedPreferences("ride_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("pending_ride_id", rideId).apply()
            
            // إنشاء نية لفتح التطبيق
            val intent = Intent(context, com.mauri_course.driver.MainActivity::class.java)
            intent.action = "OPEN_RIDE_ACTION"
            intent.putExtra("RIDE_ID", rideId)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or 
                         Intent.FLAG_ACTIVITY_CLEAR_TOP or
                         Intent.FLAG_ACTIVITY_SINGLE_TOP)
            
            // إنشاء PendingIntent
            val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val pendingIntent = PendingIntent.getActivity(context, ALARM_ID, intent, pendingFlags)
            
            // استخدام AlarmManager لتشغيل فوري
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // تشغيل فوري (بعد 100 مللي ثانية)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 100,
                    pendingIntent
                )
                
                // جدولة تشغيل ثاني بعد ثانية واحدة (للتأكيد)
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 1000,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + 100,
                    pendingIntent
                )
            }
            
            // إرسال بث مباشر أيضًا
            val broadcastIntent = Intent("com.mauri_course.driver.OPEN_APP").apply {
                putExtra("rideId", rideId)
                putExtra("isOpenRide", false)
            }
            context.sendBroadcast(broadcastIntent)
            
            Log.d(TAG, "App launch scheduled successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling app launch: ${e.message}")
            
            // محاولة بديلة لفتح التطبيق مباشرة
            try {
                val fallbackIntent = Intent(context, com.mauri_course.driver.MainActivity::class.java)
                fallbackIntent.action = "OPEN_RIDE_ACTION"
                fallbackIntent.putExtra("RIDE_ID", rideId)
                fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(fallbackIntent)
                Log.d(TAG, "Fallback app launch successful")
            } catch (fallbackException: Exception) {
                Log.e(TAG, "Fallback app launch failed: ${fallbackException.message}")
            }
        }
    }
}
