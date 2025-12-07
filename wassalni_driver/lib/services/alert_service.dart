import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

class AlertService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String channelId = 'alert_channel';

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // إنشاء قناة الإشعارات للتنبيهات العاجلة
      const channel = AndroidNotificationChannel(
        channelId,
        'تنبيهات عاجلة',
        description: 'تنبيهات مهمة وعاجلة',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        sound: RawResourceAndroidNotificationSound('notification'),
        enableLights: true,
      );

      // تسجيل القناة
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // طلب الأذونات على iOS
      if (Platform.isIOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
              critical: true,
            );
      }

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      

      final InitializationSettings settings = InitializationSettings(
        android: androidSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // معالجة النقر على الإشعار
          NotificationService.selectNotificationSubject.add(response.payload);
        },
      );

      _initialized = true;
      debugPrint('AlertService: تم تهيئة خدمة التنبيهات بنجاح');
    } catch (e) {
      debugPrint('AlertService: خطأ في تهيئة التنبيهات - $e');
    }
  }

  static Future<void> showAlert({
    required String title,
    required String body,
    required String payload,
    bool playSound = true,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId,
        'تنبيهات عاجلة',
        channelDescription: 'تنبيهات مهمة وعاجلة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: true,
        enableLights: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        interruptionLevel: InterruptionLevel.critical,
        threadIdentifier: 'alerts',
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('AlertService: تم إرسال تنبيه: $title');
    } catch (e) {
      debugPrint('AlertService: خطأ في إرسال التنبيه: $e');
    }
  }
}
