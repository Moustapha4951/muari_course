import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/shared_preferences_helper.dart';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;
  static StreamSubscription<DocumentSnapshot>? _rideSubscription;
  static String? _currentRideId;

  // Initialize notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for iOS
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('NotificationService: Initialized successfully');
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to ride details screen
  }

  // Show notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ride_updates',
      'تحديثات الرحلات',
      channelDescription: 'إشعارات حالة الرحلة',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Listen to ride updates
  static Future<void> listenToRideUpdates(String rideId) async {
    if (!_initialized) {
      await initialize();
    }

    // Cancel previous subscription
    await _rideSubscription?.cancel();
    _currentRideId = rideId;

    debugPrint('NotificationService: Listening to ride updates for $rideId');

    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final status = data['status'];
      final driverName = data['driverName'];

      debugPrint('NotificationService: Ride status changed to $status');

      // Show notification based on status
      switch (status) {
        case 'accepted':
          showNotification(
            id: 1,
            title: 'تم قبول الرحلة',
            body: 'السائق $driverName في الطريق إليك',
            payload: 'ride:$rideId',
          );
          break;
        case 'started':
          showNotification(
            id: 2,
            title: 'بدأت الرحلة',
            body: 'الرحلة جارية الآن',
            payload: 'ride:$rideId',
          );
          break;
        case 'completed':
          showNotification(
            id: 3,
            title: 'اكتملت الرحلة',
            body: 'شكراً لاستخدامك RimApp',
            payload: 'ride:$rideId',
          );
          stopListening();
          break;
        case 'cancelled':
          final cancelReason = data['cancelReason'] ?? 'لا يوجد سبب';
          showNotification(
            id: 4,
            title: 'تم إلغاء الرحلة',
            body: 'السبب: $cancelReason',
            payload: 'ride:$rideId',
          );
          stopListening();
          break;
      }
    });
  }

  // Stop listening to ride updates
  static Future<void> stopListening() async {
    await _rideSubscription?.cancel();
    _rideSubscription = null;
    _currentRideId = null;
    debugPrint('NotificationService: Stopped listening to ride updates');
  }

  // Show ride accepted notification
  static Future<void> showRideAcceptedNotification({
    required String driverName,
    required String rideId,
  }) async {
    await showNotification(
      id: 1,
      title: 'تم قبول الرحلة',
      body: 'السائق $driverName في الطريق إليك',
      payload: 'ride:$rideId',
    );
  }

  // Show ride started notification
  static Future<void> showRideStartedNotification(String rideId) async {
    await showNotification(
      id: 2,
      title: 'بدأت الرحلة',
      body: 'الرحلة جارية الآن',
      payload: 'ride:$rideId',
    );
  }

  // Show ride completed notification
  static Future<void> showRideCompletedNotification(String rideId) async {
    await showNotification(
      id: 3,
      title: 'اكتملت الرحلة',
      body: 'شكراً لاستخدامك RimApp',
      payload: 'ride:$rideId',
    );
  }

  // Show ride cancelled notification
  static Future<void> showRideCancelledNotification({
    required String rideId,
    required String reason,
  }) async {
    await showNotification(
      id: 4,
      title: 'تم إلغاء الرحلة',
      body: 'السبب: $reason',
      payload: 'ride:$rideId',
    );
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  // Cancel specific notification
  static Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
