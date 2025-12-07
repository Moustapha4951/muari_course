package com.mauri_course.driver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.KeyguardManager
import android.app.PendingIntent
import android.app.ActivityManager
import android.os.Build
import android.os.PowerManager
import android.os.Bundle
import android.content.ComponentName
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.view.WindowManager.LayoutParams

class NotificationReceiver : BroadcastReceiver() {
    private val TAG = "NotificationReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "تم استلام broadcast: ${intent.action}")
        
        if (intent.action == "com.mauri_course.driver.OPEN_APP") {
            Log.d(TAG, "استلام طلب لفتح التطبيق")
            
            // استخراج البيانات من الـ intent
            val extras = intent.extras
            val rideId = extras?.getString("rideId")
            val isOpenRide = extras?.getBoolean("isOpenRide") ?: false
            
            Log.d(TAG, "تفاصيل الرحلة: المعرف = $rideId، رحلة مفتوحة = $isOpenRide")
            
            // الحصول على PowerManager لإيقاظ الجهاز
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = powerManager?.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "wassalni_driver:wakelock"
            )

            // إيقاظ الشاشة
            wakeLock?.acquire(60 * 1000L)
            
            try {
                // إنشاء Intent لفتح التطبيق مع جميع الخيارات المطلوبة
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    action = "OPEN_RIDE_ACTION"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    putExtra("fromNotification", true)
                    putExtra("isUrgent", true)
                    putExtra("rideId", rideId)
                    putExtra("isOpenRide", isOpenRide)
                    putExtra("timestamp", System.currentTimeMillis())
                }
                
                // إضافة category launcher لضمان فتح التطبيق
                launchIntent.addCategory(Intent.CATEGORY_LAUNCHER)
                launchIntent.setPackage(context.packageName)
                
                // إنشاء PendingIntent لفتح التطبيق
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    System.currentTimeMillis().toInt(),
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                try {
                    // محاولة فتح التطبيق باستخدام PendingIntent
                    pendingIntent.send()
                    Log.d(TAG, "تم إرسال PendingIntent لفتح التطبيق")
                } catch (e: Exception) {
                    // إذا فشل PendingIntent، نحاول فتح التطبيق مباشرة
                    context.startActivity(launchIntent)
                    Log.d(TAG, "تم فتح التطبيق بشكل مباشر")
                }

            } catch (e: Exception) {
                Log.e(TAG, "خطأ في محاولة فتح التطبيق: ${e.message}")
                
                // محاولة بديلة لفتح التطبيق
                try {
                    val fallbackIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    fallbackIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    fallbackIntent?.putExtra("rideId", rideId)
                    context.startActivity(fallbackIntent)
                    Log.d(TAG, "تم فتح التطبيق باستخدام طريقة احتياطية")
                } catch (fallbackException: Exception) {
                    Log.e(TAG, "فشل في فتح التطبيق باستخدام الطريقة الاحتياطية: ${fallbackException.message}")
                }
            } finally {
                // إطلاق الـ wakeLock إذا كان لا يزال محجوزًا
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                    Log.d(TAG, "تم إطلاق wakeLock")
                }
            }
        }
    }
}
