import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/sharedpreferences_helper.dart';
import '../screens/customer_ride_screen.dart';

class CustomerRideNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static BuildContext? _context;
  static bool _initialized = false;
  static StreamSubscription<QuerySnapshot>? _ridesSubscription;
  static bool _isListening = false;
  static final Set<String> _processedRides = {};

  static void setContext(BuildContext context) {
    _context = context;
    debugPrint('CustomerRideNotificationService: Context set');
    
    if (!_isListening) {
      listenForCustomerRides();
    }
  }

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('CustomerRideNotificationService: Already initialized');
      return;
    }

    try {
      debugPrint('CustomerRideNotificationService: Starting initialization');

      const channel = AndroidNotificationChannel(
        'customer_rides_channel',
        'طلبات الزبائن',
        description: 'إشعارات طلبات الرحلات من الزبائن',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iOSSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('CustomerRideNotificationService: Notification tapped: ${response.payload}');
          if (response.payload != null) {
            _processNotificationPayload(response.payload!);
          }
        },
      );

      _initialized = true;
      debugPrint('CustomerRideNotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Initialization error: $e');
    }
  }

  static void _processNotificationPayload(String payload) {
    if (_context == null) return;

    final parts = payload.split(':');
    if (parts.length == 2 && parts[0] == 'customer_ride') {
      final rideId = parts[1];
      Navigator.push(
        _context!,
        MaterialPageRoute(
          builder: (_) => CustomerRideScreen(rideId: rideId),
        ),
      );
    }
  }

  static Future<void> listenForCustomerRides() async {
    if (_isListening) {
      debugPrint('CustomerRideNotificationService: Already listening');
      return;
    }

    try {
      if (!_initialized) {
        await initialize();
      }

      final driverId = await SharedPreferencesHelper.getUserId();
      if (driverId == null) {
        debugPrint('CustomerRideNotificationService: No driver ID found');
        return;
      }

      final city = await SharedPreferencesHelper.getUserCity();
      if (city == null || city.isEmpty) {
        debugPrint('CustomerRideNotificationService: No city found');
        return;
      }

      debugPrint('CustomerRideNotificationService: Starting listener for city: $city');

      _ridesSubscription = FirebaseFirestore.instance
          .collection('rides')
          .where('cityId', isEqualTo: city)
          .where('status', isEqualTo: 'pending')
          .where('isOpen', isEqualTo: false) // Only customer rides (not open rides)
          .snapshots()
          .listen(
        (snapshot) async {
          debugPrint('CustomerRideNotificationService: Snapshot received with ${snapshot.docs.length} rides');

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final rideId = change.doc.id;
              final rideData = change.doc.data() as Map<String, dynamic>;

              debugPrint('CustomerRideNotificationService: New ride detected: $rideId');

              // Skip if already processed
              if (_processedRides.contains(rideId)) {
                debugPrint('CustomerRideNotificationService: Ride $rideId already processed');
                continue;
              }

              try {
                // Check if should show notification
                final shouldShow = await _shouldShowRideNotification(rideData);
                
                if (shouldShow) {
                  await _showCustomerRideNotification(
                    rideId: rideId,
                    rideData: rideData,
                  );
                  _processedRides.add(rideId);
                }
              } catch (e) {
                debugPrint('CustomerRideNotificationService: Error processing ride $rideId: $e');
              }
            }
          }
        },
        onError: (error) {
          debugPrint('CustomerRideNotificationService: Listener error: $error');
          _isListening = false;
        },
      );

      _isListening = true;
      debugPrint('CustomerRideNotificationService: Listener started successfully');
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Error in listenForCustomerRides: $e');
    }
  }

  static Future<bool> _shouldShowRideNotification(Map<String, dynamic> rideData) async {
    try {
      // Check driver status
      final driverId = await SharedPreferencesHelper.getUserId();
      if (driverId == null) return false;

      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) return false;

      final driverData = driverDoc.data()!;
      final driverStatus = driverData['status'];
      final driverBalance = driverData['balance'];

      // Don't show if driver is busy
      if (driverStatus == 'busy') {
        debugPrint('CustomerRideNotificationService: Driver is busy');
        return false;
      }

      // Don't show if balance is insufficient
      if (driverBalance != null && driverBalance <= 0) {
        debugPrint('CustomerRideNotificationService: Insufficient balance');
        return false;
      }

      // Check ride age (don't show rides older than 30 seconds)
      final createdAt = rideData['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final rideAge = DateTime.now().difference(createdAt.toDate());
        if (rideAge.inSeconds > 30) {
          debugPrint('CustomerRideNotificationService: Ride too old (${rideAge.inSeconds}s)');
          return false;
        }
      }

      // Check distance
      final pickupLocation = rideData['pickupLocation'] as GeoPoint?;
      if (pickupLocation == null) return false;

      final maxDistance = await _getMaxRideDistance();
      final isWithinRange = await _isWithinRange(pickupLocation, maxDistance);
      
      if (!isWithinRange) {
        debugPrint('CustomerRideNotificationService: Ride outside range');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Error in _shouldShowRideNotification: $e');
      return false;
    }
  }

  static Future<double> _getMaxRideDistance() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('ride_settings')
          .get();

      if (settingsDoc.exists) {
        final data = settingsDoc.data();
        return (data?['maxRideDistance'] ?? 1.0).toDouble();
      }
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Error getting max distance: $e');
    }
    return 1.0; // Default 1km
  }

  static Future<bool> _isWithinRange(GeoPoint pickupLocation, double maxDistanceKm) async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        );
      }

      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        pickupLocation.latitude,
        pickupLocation.longitude,
      );

      double distanceInKm = distanceInMeters / 1000;
      return distanceInKm <= maxDistanceKm;
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Error calculating distance: $e');
      return true; // Accept ride on error
    }
  }

  static Future<void> _showCustomerRideNotification({
    required String rideId,
    required Map<String, dynamic> rideData,
  }) async {
    try {
      final pickupAddress = rideData['pickupAddress'] ?? 'غير محدد';
      final customerName = rideData['customerName'] ?? 'زبون';
      final fare = rideData['fare']?.toDouble() ?? 0.0;

      const androidDetails = AndroidNotificationDetails(
        'customer_rides_channel',
        'طلبات الزبائن',
        channelDescription: 'إشعارات طلبات الرحلات من الزبائن',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _notificationsPlugin.show(
        rideId.hashCode,
        '🚖 طلب رحلة جديد من $customerName',
        'من: $pickupAddress • السعر: ${fare.toStringAsFixed(2)} MRU',
        notificationDetails,
        payload: 'customer_ride:$rideId',
      );

      debugPrint('CustomerRideNotificationService: Notification shown for ride $rideId');

      // Auto-open screen if context is available
      if (_context != null) {
        Navigator.push(
          _context!,
          MaterialPageRoute(
            builder: (_) => CustomerRideScreen(rideId: rideId),
          ),
        );
      }
    } catch (e) {
      debugPrint('CustomerRideNotificationService: Error showing notification: $e');
    }
  }

  static Future<void> stopListening() async {
    await _ridesSubscription?.cancel();
    _ridesSubscription = null;
    _isListening = false;
    _processedRides.clear();
    debugPrint('CustomerRideNotificationService: Stopped listening');
  }

  static void clearProcessedRides() {
    _processedRides.clear();
    debugPrint('CustomerRideNotificationService: Cleared processed rides');
  }
}
