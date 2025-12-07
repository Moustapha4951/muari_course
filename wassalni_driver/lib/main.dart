import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

import 'package:rimapp_driver/utils/sharedpreferences_helper.dart';
import 'package:rimapp_driver/utils/app_theme.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/ride_screen_new_version.dart';
import 'screens/open_ride_screen_v2.dart';
import 'screens/customer_ride_screen.dart';

Future<void> _checkForPendingRides() async {
  final pendingRideId = await SharedPreferencesHelper.getPendingRideId();

  if (pendingRideId != null && pendingRideId.isNotEmpty) {
    debugPrint('تم العثور على رحلة معلقة عند بدء التطبيق: $pendingRideId');

    try {
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(pendingRideId)
          .get();

      if (rideDoc.exists && rideDoc.data()?['status'] == 'pending') {
        await SharedPreferencesHelper.setPendingRideId(pendingRideId);
      } else {
        await SharedPreferencesHelper.clearPendingRideId();
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من الرحلة المعلقة: $e');
    }
  }
}

Future<void> _setupNotificationChannels() async {
  if (Platform.isAndroid) {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'رحلات جديدة - عالية الأهمية',
        description: 'قناة للإشعارات المهمة جدًا التي تفتح التطبيق تلقائيًا',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint('تم إنشاء قناة الإشعارات عالية الأهمية');
    } catch (e) {
      debugPrint('خطأ في إنشاء قناة الإشعارات: $e');
    }
  }
}

Future<void> _startForegroundService() async {
  try {
    const platform = MethodChannel('com.muari_course.driver/app_launcher');
    // إزالة استدعاء startForegroundService لأنه غير موجود في MainActivity
    debugPrint('تم تخطي بدء تشغيل الخدمة الخلفية');
  } catch (e) {
    debugPrint('خطأ في بدء تشغيل الخدمة الخلفية: $e');
  }
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _setupNotificationChannels();
  await _startForegroundService();
  await _checkForPendingRides();
  await NotificationService.initialize(); // Handles both admin open rides and customer rides
}

void main() async {
  try {
    await _bootstrap();
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error in main: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('فشل بدء التطبيق: $e'),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muari Course - سائق',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
      ],
      locale: const Locale('ar', ''),
      home: const SplashScreen(),
      routes: {
        '/new_ride': (context) => RideScreenNewVersion(rideData: const {}, rideId: ''),
        '/open_ride': (context) => OpenRideScreenV2(rideData: const {}, rideId: ''),
      },
      // ربط السياق مع خدمة الإشعارات لفتح الشاشات عند النقر على الإشعار
      builder: (context, child) {
        NotificationService.setContext(context);
        return child!;
      },
    );
  }
}
