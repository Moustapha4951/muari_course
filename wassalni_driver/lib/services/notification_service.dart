import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Add this import for Int64List
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/sharedpreferences_helper.dart';
import 'package:rxdart/rxdart.dart';
import '../screens/ride_screen_new_version.dart';
import '../screens/open_ride_screen_v2.dart';
import '../screens/customer_ride_screen.dart';
import '../screens/driver_open_trip_screen.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static BuildContext? _context;
  static bool _initialized = false;
  static StreamSubscription<QuerySnapshot>? _ridesSubscription;

  // استخدام BehaviorSubject لتتبع النقر على الإشعارات
  static final BehaviorSubject<String?> selectNotificationSubject =
      BehaviorSubject<String?>();

  // معرف قناة الإشعارات
  static const String channelId = 'rides_channel';

  // متغير للتأكد من تشغيل المراقبة
  static bool _isListening = false;

  static void setContext(BuildContext context) {
    _context = context;
    debugPrint('NotificationService: تم تعيين السياق');

    // عند تعيين السياق، نبدأ المراقبة تلقائيًا
    if (!_isListening) {
      listenForNewRides();
    }
  }

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('🔵 [LOGGING] NotificationService already initialized');
      return;
    }

    try {
      debugPrint('🔵 [LOGGING] NotificationService: Starting initialization');
      debugPrint('NotificationService: بدء تهيئة خدمة الإشعارات');

      // إنشاء قناة الإشعارات بأعلى أولوية
      const channel = AndroidNotificationChannel(
        channelId,
        'رحلات جديدة',
        description: 'إشعارات الرحلات الجديدة',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification'),
      );

      // تسجيل القناة
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // تبسيط إعدادات التهيئة
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOSSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings =
          InitializationSettings(android: androidSettings, iOS: iOSSettings);

      // تهيئة التنبيهات مع معالج النقر
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
              'NotificationService: تم النقر على الإشعار: ${response.payload}');
          if (response.payload != null) {
            selectNotificationSubject.add(response.payload);
          }
        },
      );

      // الاستماع لأحداث النقر على الإشعار
      selectNotificationSubject.stream.listen((String? payload) {
        if (payload != null && payload.isNotEmpty) {
          _processNotificationPayload(payload);
        }
      });

      _initialized = true;
      debugPrint(
          '🔵 [LOGGING] NotificationService: Initialization completed successfully');
      debugPrint('NotificationService: تم تهيئة خدمة الإشعارات بنجاح');
    } catch (e) {
      debugPrint(
          '🔴 [LOGGING] NotificationService: Initialization failed - $e');
      debugPrint('NotificationService: خطأ في تهيئة الإشعارات - $e');
    }
  }

  // معالجة بيانات الإشعار عند النقر
  static Future<void> _processNotificationPayload(String payload) async {
    try {
      debugPrint('🔵 [LOGGING] Processing notification payload: $payload');
      final Map<String, dynamic> payloadData = _parsePayload(payload);
      debugPrint('🔵 [LOGGING] Parsed payload data: $payloadData');
      debugPrint('NotificationService: معالجة بيانات الإشعار: $payloadData');

      if (payloadData.containsKey('rideId')) {
        final rideId = payloadData['rideId'];
        debugPrint('🔵 [LOGGING] Fetching ride document for rideId: $rideId');

        final rideDoc = await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideId)
            .get();

        debugPrint(
            '🔵 [LOGGING] Ride exists: ${rideDoc.exists}, Status: ${rideDoc.data()?['status']}');

        if (rideDoc.exists && rideDoc.data()?['status'] == 'pending') {
          debugPrint('🟢 [LOGGING] Ride is available, opening ride screen');
          await _openRideScreen(rideId, rideDoc.data() ?? {});
        } else {
          debugPrint('🟡 [LOGGING] Ride not available or already accepted');
          debugPrint(
              'NotificationService: الرحلة غير متاحة أو تم قبولها بالفعل');
        }
      } else {
        debugPrint('🔴 [LOGGING] No rideId found in payload');
      }
    } catch (e) {
      debugPrint('🔴 [LOGGING] Error processing notification payload - $e');
      debugPrint('NotificationService: خطأ في معالجة بيانات الإشعار - $e');
    }
  }

  static Map<String, dynamic> _parsePayload(String payload) {
    final Map<String, dynamic> result = {};
    try {
      final parts = payload.split('&');
      for (var part in parts) {
        final keyValue = part.split('=');
        if (keyValue.length == 2) {
          result[keyValue[0]] = keyValue[1];
        }
      }
    } catch (e) {
      debugPrint('NotificationService: خطأ في تحليل بيانات الإشعار - $e');
    }
    return result;
  }

  static Future<void> _openRideScreen(
      String rideId, Map<String, dynamic> rideData) async {
    try {
      debugPrint('🔵 [LOGGING] _openRideScreen called for rideId: $rideId');
      debugPrint('🔵 [LOGGING] Ride data: $rideData');
      debugPrint(
          'NotificationService: محاولة فتح شاشة الرحلة - rideId: $rideId');

      // التأكد من أن السياق متاح
      if (_context == null || !_context!.mounted) {
        debugPrint(
            'NotificationService: السياق غير متاح، محاولة الانتظار للسياق...');

        // محاولة مستمرة للتحقق من توفر السياق خلال 3 ثوانٍ
        int attempts = 0;
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          attempts++;
          if (_context != null && _context!.mounted) {
            timer.cancel();
            debugPrint(
                'NotificationService: تم العثور على السياق بعد $attempts محاولات');
            await _completeOpenRideScreen(rideId, rideData);
          } else if (attempts >= 6) {
            // بعد 3 ثوانٍ
            timer.cancel();
            debugPrint(
                'NotificationService: فشل في العثور على السياق بعد $attempts محاولات');
          }
        });
        return;
      }

      await _completeOpenRideScreen(rideId, rideData);
    } catch (e) {
      debugPrint('NotificationService: خطأ في فتح شاشة الرحلة - $e');
    }
  }

  static Future<void> _completeOpenRideScreen(
      String rideId, Map<String, dynamic> rideData) async {
    try {
      debugPrint(
          '🔵 [LOGGING] _completeOpenRideScreen called for rideId: $rideId');

      // فحص سريع للتأكد من أن الرحلة لا تزال متاحة
      final freshRideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .get();

      debugPrint('🔵 [LOGGING] Fresh ride doc exists: ${freshRideDoc.exists}');

      if (freshRideDoc.exists) {
        final freshData = freshRideDoc.data();
        debugPrint('🔵 [LOGGING] Fresh ride status: ${freshData?['status']}');
        debugPrint('🔵 [LOGGING] Fresh ride data: $freshData');
      }

      if (!freshRideDoc.exists || freshRideDoc.data()?['status'] != 'pending') {
        debugPrint(
            '🟡 [LOGGING] Ride no longer available - exists: ${freshRideDoc.exists}, status: ${freshRideDoc.data()?['status']}');

        if (_context != null && _context!.mounted) {
          ScaffoldMessenger.of(_context!).showSnackBar(
            const SnackBar(
              content: Text('تم قبول هذه الرحلة بالفعل من قبل سائق آخر'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Determine ride source and type
      final isOpen = freshRideDoc.data()?['isOpen'] ?? false;
      final customerId = freshRideDoc.data()?['customerId'];
      final isFromCustomerApp = customerId != null && customerId.isNotEmpty;

      String rideType;
      if (isFromCustomerApp && isOpen) {
        rideType = 'Customer Open Ride';
      } else if (isFromCustomerApp && !isOpen) {
        rideType = 'Customer Normal Ride';
      } else if (!isFromCustomerApp && isOpen) {
        rideType = 'Admin Open Ride';
      } else {
        rideType = 'Admin Normal Ride';
      }

      debugPrint('🔵 [LOGGING] NotificationService: Ride Type: $rideType');
      debugPrint('🔵 [LOGGING] isOpen: $isOpen, customerId: $customerId');

      if (_context != null && _context!.mounted) {
        debugPrint('🔵 [LOGGING] Context is mounted, proceeding with navigation');

        // إغلاق أي شاشات حالية قبل فتح شاشة الرحلة
        Navigator.of(_context!, rootNavigator: true)
            .popUntil((route) => route.isFirst);

        await Future.delayed(const Duration(milliseconds: 100));

        debugPrint('🔵 [LOGGING] Navigating to screen for: $rideType');

        // Route to appropriate screen based on ride type
        Widget screen;
        if (isFromCustomerApp && isOpen) {
          // Customer app + open ride - use DriverOpenTripScreen with meters
          screen = DriverOpenTripScreen(
            key: UniqueKey(),
            rideId: rideId,
          );
        } else if (isFromCustomerApp && !isOpen) {
          // Customer app + normal ride
          screen = CustomerRideScreen(
            key: UniqueKey(),
            rideId: rideId,
          );
        } else if (!isFromCustomerApp && isOpen) {
          // Admin app + open ride
          screen = OpenRideScreenV2(
            key: UniqueKey(),
            rideData: freshRideDoc.data()!,
            rideId: rideId,
          );
        } else {
          // Admin app + normal ride
          screen = RideScreenNewVersion(
            key: UniqueKey(),
            rideData: freshRideDoc.data()!,
            rideId: rideId,
          );
        }

        await Navigator.of(_context!, rootNavigator: true).push(
          MaterialPageRoute(builder: (context) => screen),
        );
        
        debugPrint('🟢 [LOGGING] NotificationService: تم فتح شاشة الرحلة بنجاح');
      } else {
        debugPrint('🔴 [LOGGING] Context is not mounted, cannot navigate');

        // محاولة بديلة لإنشاء سياق جديد
        try {
          debugPrint('🟡 [LOGGING] Trying to create new context...');
          // يمكن إضافة منطق إضافي هنا لإنشاء سياق جديد إذا لزم الأمر
        } catch (contextError) {
          debugPrint(
              '🔴 [LOGGING] Failed to create new context: $contextError');
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
          '🔴 [LOGGING] NotificationService: خطأ في _completeOpenRideScreen - $e');
      debugPrint('🔴 [LOGGING] Stack trace: $stackTrace');

      // محاولة بديلة لفتح الشاشة
      try {
        debugPrint('🟡 [LOGGING] Trying fallback navigation...');
        await Future.delayed(const Duration(seconds: 1));
        if (_context != null && _context!.mounted) {
          // إعادة المحاولة
          await Navigator.of(_context!, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (context) => rideData['isOpenRide'] == true ||
                      rideData['rideType'] == 'open'
                  ? OpenRideScreenV2(
                      key: UniqueKey(),
                      rideData: rideData,
                      rideId: rideId,
                    )
                  : RideScreenNewVersion(
                      key: UniqueKey(),
                      rideData: rideData,
                      rideId: rideId,
                    ),
            ),
          );
        }
      } catch (fallbackError) {
        debugPrint(
            '🔴 [LOGGING] Fallback navigation also failed: $fallbackError');
      }
    }
  }

  // الاحتفاظ بوظيفة فحص المسافة بصيغة أكثر كفاءة
  static Future<bool> _isWithinRange(
      GeoPoint pickupLocation, double maxDistanceKm) async {
    try {
      debugPrint('🔵 [LOGGING] _isWithinRange: Starting distance check');
      debugPrint(
          '🔵 [LOGGING] _isWithinRange: Pickup location - lat=${pickupLocation.latitude}, lng=${pickupLocation.longitude}');
      debugPrint(
          '🔵 [LOGGING] _isWithinRange: Max distance allowed: $maxDistanceKm km');

      // استخدام آخر موقع معروف للسرعة
      Position? position = await Geolocator.getLastKnownPosition();

      debugPrint(
          '🔵 [LOGGING] _isWithinRange: Last known position: ${position != null ? "lat=${position.latitude}, lng=${position.longitude}" : "null"}');

      // إذا لم يكن هناك موقع محفوظ، نحصل على الموقع الحالي بدقة منخفضة
      if (position == null) {
        debugPrint(
            '🔵 [LOGGING] _isWithinRange: No cached position, getting current position...');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low, // استخدام دقة منخفضة للسرعة
          timeLimit: const Duration(seconds: 3), // تحديد وقت الطلب
        );
        debugPrint(
            '🔵 [LOGGING] _isWithinRange: Current position obtained - lat=${position.latitude}, lng=${position.longitude}');
      }

      // حساب المسافة
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        pickupLocation.latitude,
        pickupLocation.longitude,
      );

      double distanceInKm = distanceInMeters / 1000;
      debugPrint(
          '🔵 [LOGGING] _isWithinRange: Distance calculated - ${distanceInKm.toStringAsFixed(2)} km');
      debugPrint(
          '🔵 [LOGGING] _isWithinRange: Within range check - ${distanceInKm <= maxDistanceKm} (distance: $distanceInKm km <= max: $maxDistanceKm km)');

      return distanceInKm <= maxDistanceKm;
    } catch (e) {
      debugPrint(
          '🔴 [LOGGING] _isWithinRange: Error calculating distance - $e');
      debugPrint(
          '🔴 [LOGGING] _isWithinRange: Returning true (accepting ride) due to error');
      return true; // قبول الرحلة في حالة الخطأ
    }
  }

  // Get maximum ride distance from Firestore settings (default 1km)
  static Future<double> _getMaxRideDistance() async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('rideSettings')
          .get();

      if (settingsDoc.exists) {
        final maxDistance = settingsDoc.data()?['maxRideDistanceKm'];
        if (maxDistance != null) {
          return (maxDistance as num).toDouble();
        }
      }
      
      // Default to 1km if no setting found
      debugPrint('🟡 [LOGGING] _getMaxRideDistance: No setting found, using default 1km');
      return 1.0;
    } catch (e) {
      debugPrint('🔴 [LOGGING] _getMaxRideDistance: Error - $e, using default 1km');
      return 1.0;
    }
  }

  // إعادة كتابة دالة الاستماع للرحلات بطريقة أبسط
  static Future<void> listenForNewRides() async {
    // إلغاء الاشتراك السابق
    await _ridesSubscription?.cancel();
    _isListening = false;

    debugPrint('🔵 [LOGGING] ========================================');
    debugPrint(
        '🔵 [LOGGING] listenForNewRides: Starting to listen for new rides');
    debugPrint('🔵 [LOGGING] listenForNewRides: Timestamp: ${DateTime.now()}');

    try {
      if (!_initialized) {
        debugPrint(
            '🔵 [LOGGING] listenForNewRides: Service not initialized, initializing now...');
        await initialize();
      }

      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];
      final city = driverData['city'];

      debugPrint('🔵 [LOGGING] listenForNewRides: Driver data retrieved');
      debugPrint('🔵 [LOGGING] listenForNewRides: - driverId: $driverId');
      debugPrint('🔵 [LOGGING] listenForNewRides: - city: $city');

      if (driverId == null) {
        debugPrint(
            '🔴 [LOGGING] listenForNewRides: CRITICAL - driverId is null, cannot listen for rides');
        return;
      }

      if (city == null) {
        debugPrint(
            '🟡 [LOGGING] listenForNewRides: WARNING - city is null, this may affect ride matching');
      }

      // Check driver balance and status
      debugPrint(
          '🔵 [LOGGING] listenForNewRides: Fetching driver document from Firestore...');
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final driverDocData = driverDoc.data();
        final balance = driverDocData?['balance'];
        final status = driverDocData?['status'];
        debugPrint('🔵 [LOGGING] listenForNewRides: Driver document found');
        debugPrint('🔵 [LOGGING] listenForNewRides: - balance: $balance');
        debugPrint('🔵 [LOGGING] listenForNewRides: - status: $status');

        if (balance != null && balance <= 0) {
          debugPrint(
              '🔴 [LOGGING] listenForNewRides: CRITICAL - Driver balance is insufficient ($balance), rides will not be shown');
        } else {
          debugPrint(
              '🟢 [LOGGING] listenForNewRides: Driver balance is sufficient ($balance)');
        }

        if (status != 'available') {
          debugPrint(
              '🟡 [LOGGING] listenForNewRides: WARNING - Driver status is "$status", not "available"');
        }
      } else {
        debugPrint(
            '🔴 [LOGGING] listenForNewRides: CRITICAL - Driver document not found for driverId: $driverId');
        return;
      }

      // إزالة التعقيدات في الاستعلام - فقط الاستعلام عن الرحلات المعلقة في نفس المدينة
      debugPrint(
          '🔵 [LOGGING] listenForNewRides: Setting up Firestore listener');
      debugPrint(
          '🔵 [LOGGING] listenForNewRides: Query filters - status: pending, cityId: $city');

      _ridesSubscription = FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .where('cityId', isEqualTo: city)
          // Listen for ALL rides (both open rides from admin and customer rides)
          .snapshots()
          .listen(
        (snapshot) async {
          debugPrint('🔵 [LOGGING] ========================================');
          debugPrint(
              '🔵 [LOGGING] Firestore Snapshot Received: ${DateTime.now()}');
          debugPrint(
              '🔵 [LOGGING] Snapshot: Total rides in snapshot: ${snapshot.docs.length}');
          debugPrint(
              '🔵 [LOGGING] Snapshot: Document changes: ${snapshot.docChanges.length}');

          for (var change in snapshot.docChanges) {
            debugPrint('🔵 [LOGGING] Snapshot: Change type: ${change.type}');

            if (change.type == DocumentChangeType.added) {
              try {
                final rideId = change.doc.id;
                final Map<String, dynamic>? rideData = change.doc.data();

                debugPrint(
                    '🔵 [LOGGING] ----------------------------------------');
                debugPrint('🟢 [LOGGING] NEW RIDE DETECTED!');
                debugPrint('🔵 [LOGGING] Ride ID: $rideId');
                debugPrint('🔵 [LOGGING] Ride status: ${rideData?['status']}');
                debugPrint('🔵 [LOGGING] Ride cityId: ${rideData?['cityId']}');
                debugPrint(
                    '🔵 [LOGGING] Ride pickup: ${rideData?['pickupAddress']}');
                debugPrint(
                    '🔵 [LOGGING] Ride dropoff: ${rideData?['dropoffAddress']}');
                debugPrint('🔵 [LOGGING] Ride fare: ${rideData?['fare']}');
                debugPrint(
                    '🔵 [LOGGING] Ride type: ${rideData?['rideType']} / isOpenRide: ${rideData?['isOpenRide']}');
                debugPrint(
                    '🔵 [LOGGING] Full ride data: ${rideData.toString()}');

                if (rideData == null) {
                  debugPrint(
                      '🔴 [LOGGING] CRITICAL - Ride data is null for rideId: $rideId');
                  continue;
                }

                // تحقق من عدم وجود سائق معين للرحلة
                final assignedDriverId = rideData['assignedDriverId'];
                debugPrint(
                    '🔵 [LOGGING] Checking assignedDriverId: $assignedDriverId');

                if (assignedDriverId == null) {
                  // Check if this ride has nearbyDriverIds restriction
                  final nearbyDriverIds = rideData['nearbyDriverIds'] as List?;
                  
                  if (nearbyDriverIds != null && nearbyDriverIds.isNotEmpty) {
                    // This ride is restricted to nearby drivers only
                    if (!nearbyDriverIds.contains(driverId)) {
                      debugPrint(
                          '🟡 [LOGGING] ✗ Driver $driverId is not in nearbyDriverIds list - skipping');
                      continue;
                    }
                    debugPrint(
                        '🟢 [LOGGING] ✓ Driver $driverId is in nearbyDriverIds list');
                  }

                  final pickupAddress =
                      rideData['pickupAddress'] as String? ?? 'موقع غير معروف';

                  debugPrint(
                      '🟢 [LOGGING] ✓ Ride is available (no assigned driver)');
                  debugPrint('🔵 [LOGGING] Calling showRideNotification...');

                  // استدعاء دالة عرض الإشعار
                  await showRideNotification(
                    rideId: rideId,
                    pickupAddress: pickupAddress,
                    rideData: rideData,
                  );

                  debugPrint(
                      '🔵 [LOGGING] showRideNotification call completed');
                } else {
                  debugPrint(
                      '🟡 [LOGGING] ✗ Ride already assigned to driver: $assignedDriverId - skipping');
                }
              } catch (e, stackTrace) {
                debugPrint('🔴 [LOGGING] ERROR processing ride change: $e');
                debugPrint('🔴 [LOGGING] Stack trace: $stackTrace');
              }
            }
          }
        },
        onError: (error) {
          debugPrint('🔴 [LOGGING] ========================================');
          debugPrint('🔴 [LOGGING] FIRESTORE LISTENER ERROR: $error');
          debugPrint(
              '🔴 [LOGGING] Listener stopped, _isListening set to false');
          _isListening = false;
        },
      );

      _isListening = true;
      debugPrint('🟢 [LOGGING] ========================================');
      debugPrint('🟢 [LOGGING] ✓ Firestore listener successfully started');
      debugPrint('🟢 [LOGGING] ✓ Now listening for rides in city: $city');
      debugPrint('🟢 [LOGGING] ========================================');
    } catch (e, stackTrace) {
      debugPrint('🔴 [LOGGING] ========================================');
      debugPrint('🔴 [LOGGING] CRITICAL ERROR in listenForNewRides: $e');
      debugPrint('🔴 [LOGGING] Stack trace: $stackTrace');
      debugPrint('🔴 [LOGGING] ========================================');
    }
  }

  // تعديل دالة showRideNotification لتضمين فحص المسافة
  static Future<void> showRideNotification({
    required String rideId,
    required String pickupAddress,
    required Map<String, dynamic> rideData,
  }) async {
    try {
      debugPrint('🔵 [LOGGING] ========================================');
      debugPrint('🔵 [LOGGING] showRideNotification: CALLED');
      debugPrint('🔵 [LOGGING] showRideNotification: rideId: $rideId');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: pickupAddress: $pickupAddress');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Timestamp: ${DateTime.now()}');

      if (!_initialized) {
        debugPrint(
            '🔵 [LOGGING] showRideNotification: Service not initialized, initializing...');
        await initialize();
      }

      // فحص حالة السائق
      final driverId = await SharedPreferencesHelper.getUserId();
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Retrieved driverId: $driverId');

      if (driverId == null) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: BLOCKED - Driver ID is null');
        return;
      }

      debugPrint(
          '🔵 [LOGGING] showRideNotification: Fetching driver document...');
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: BLOCKED - Driver document does not exist');
        return;
      }

      final driverData = driverDoc.data();
      final driverStatus = driverData?['status'];
      final driverBalance = driverData?['balance'];

      debugPrint(
          '🔵 [LOGGING] showRideNotification: Driver document retrieved');
      debugPrint('🔵 [LOGGING] showRideNotification: - status: $driverStatus');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: - balance: $driverBalance');

      // Check driver status
      if (driverStatus == 'busy') {
        debugPrint(
            '🟡 [LOGGING] showRideNotification: BLOCKED - Driver is busy');
        return;
      } else {
        debugPrint(
            '🟢 [LOGGING] showRideNotification: ✓ Driver status check passed ($driverStatus)');
      }

      // Check driver balance - THIS IS CRITICAL
      if (driverBalance != null && driverBalance <= 0) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: BLOCKED - Driver balance is insufficient: $driverBalance');
        debugPrint(
            '🔴 [LOGGING] showRideNotification: THIS IS THE PROBLEM - Balance must be > 0');
        return;
      } else {
        debugPrint(
            '🟢 [LOGGING] showRideNotification: ✓ Driver balance check passed ($driverBalance)');
      }

      // Check ride age - rides older than 30 seconds should not be shown
      final createdAt = rideData['createdAt'] as Timestamp?;
      if (createdAt != null) {
        final rideAge = DateTime.now().difference(createdAt.toDate());
        debugPrint(
            '🔵 [LOGGING] showRideNotification: Ride age: ${rideAge.inSeconds} seconds');
        
        if (rideAge.inSeconds > 30) {
          debugPrint(
              '🟡 [LOGGING] showRideNotification: BLOCKED - Ride is older than 30 seconds (${rideAge.inSeconds}s)');
          return;
        }
      }

      // إضافة فحص المسافة
      final pickupLocation = rideData['pickupLocation'] as GeoPoint?;
      if (pickupLocation == null) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: BLOCKED - Pickup location is null');
        return;
      }

      debugPrint(
          '🔵 [LOGGING] showRideNotification: Pickup location - lat=${pickupLocation.latitude}, lng=${pickupLocation.longitude}');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Checking distance range...');

      // Get maximum distance from settings (default 1km)
      final maxDistance = await _getMaxRideDistance();
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Max distance configured: $maxDistance km');

      // التحقق من أن المسافة لا تزيد عن المسافة المحددة
      final isWithinRange = await _isWithinRange(pickupLocation, maxDistance);
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Distance check result: $isWithinRange');

      if (!isWithinRange) {
        debugPrint(
            '🟡 [LOGGING] showRideNotification: BLOCKED - Ride is outside $maxDistance km range');
        return;
      } else {
        debugPrint(
            '🟢 [LOGGING] showRideNotification: ✓ Distance check passed (within 50 km)');
      }

      // متابعة إرسال الإشعار...
      debugPrint(
          '🟢 [LOGGING] showRideNotification: ✓✓✓ ALL CHECKS PASSED ✓✓✓');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Proceeding to show notification...');

      await SharedPreferencesHelper.setPendingRideId(rideId);
      debugPrint('🔵 [LOGGING] showRideNotification: Pending ride ID saved');

      // محاولة فتح التطبيق عبر MethodChannel
      try {
        debugPrint(
            '🔵 [LOGGING] showRideNotification: Attempting to launch app via MethodChannel...');
        const platform = MethodChannel('com.muari_course.driver/app_launcher');
        await platform.invokeMethod('launchApp', {
          'rideId': rideId,
          'pickupAddress': pickupAddress,
        });
        debugPrint(
            '🟢 [LOGGING] showRideNotification: ✓ App launch method invoked successfully');
      } catch (e) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: Error launching app via MethodChannel: $e');
        // Fallback to direct notification
        await _showDirectNotification(rideId, pickupAddress);
      }

      // عرض إشعار مع صوت
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Creating notification details...');
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'rides_channel',
        'رحلات جديدة',
        channelDescription: 'إشعارات الرحلات الجديدة',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('notification'),
        playSound: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        ledColor: const Color.fromARGB(255, 0, 255, 0),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Notification ID: $notificationId');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Notification title: "رحلة جديدة متاحة!"');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Notification body: "رحلة جديدة من $pickupAddress"');
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Notification payload: "rideId=$rideId"');

      // عرض إشعار عادي
      debugPrint(
          '🔵 [LOGGING] showRideNotification: Calling _notificationsPlugin.show()...');
      await _notificationsPlugin.show(
        notificationId,
        'رحلة جديدة متاحة!',
        'رحلة جديدة من $pickupAddress',
        notificationDetails,
        payload: 'rideId=$rideId',
      );

      debugPrint(
          '🟢 [LOGGING] showRideNotification: ✓ Notification displayed successfully!');
      debugPrint('🔵 [LOGGING] showRideNotification: Opening ride screen...');

      // فتح شاشة الرحلة تلقائيًا بعد تأخير قصير
      await Future.delayed(const Duration(seconds: 1));
      _openRideScreen(rideId, rideData);

      debugPrint('🟢 [LOGGING] showRideNotification: COMPLETED SUCCESSFULLY');
      debugPrint('🟢 [LOGGING] ========================================');
    } catch (e, stackTrace) {
      debugPrint('🔴 [LOGGING] ========================================');
      debugPrint('🔴 [LOGGING] showRideNotification: CRITICAL ERROR: $e');
      debugPrint('🔴 [LOGGING] showRideNotification: Stack trace: $stackTrace');
      debugPrint('🔴 [LOGGING] ========================================');

      // محاولة بديلة لفتح شاشة الرحلة في حالة حدوث خطأ
      try {
        debugPrint(
            '🟡 [LOGGING] showRideNotification: Trying fallback method...');
        await Future.delayed(const Duration(seconds: 2));
        _openRideScreen(rideId, rideData);
      } catch (fallbackError) {
        debugPrint(
            '🔴 [LOGGING] showRideNotification: Fallback method also failed: $fallbackError');
      }
    }
  }

  // دالة لإظهار إشعار مباشر كاحتياطي
  static Future<void> _showDirectNotification(
      String rideId, String pickupAddress) async {
    try {
      const platform = MethodChannel('com.rimapp.driver/app_launcher');
      await platform.invokeMethod('showNotification', {
        'rideId': rideId,
        'pickupAddress': pickupAddress,
      });
    } catch (e) {
      debugPrint('🔴 [LOGGING] _showDirectNotification: Error: $e');
    }
  }

  // تحسين دالة _launchAppFromBackground
  static Future<void> _launchAppFromBackground(String rideId) async {
    try {
      const platform = MethodChannel('com.rimapp.driver/app_launcher');

      // محاولة التحقق من وتعطيل تحسينات البطارية
      try {
        await platform.invokeMethod('checkBatteryOptimization');
      } catch (e) {
        debugPrint('خطأ في التحقق من تحسينات البطارية: $e');
      }

      // محاولة فتح التطبيق
      final result =
          await platform.invokeMethod('launchApp', {'rideId': rideId});
      debugPrint('نتيجة محاولة فتح التطبيق: $result');
    } catch (e) {
      debugPrint('خطأ في دالة _launchAppFromBackground: $e');
      rethrow;
    }
  }

  // تحسين دالة showTestRideNotification للتأكد من فتح الشاشة الصحيحة
  static Future<void> showTestRideNotification({
    required String rideId,
    required String pickupAddress,
    required Map<String, dynamic> rideData,
  }) async {
    try {
      debugPrint(
          'NotificationService: محاولة عرض إشعار اختباري للرحلة $rideId');

      // 🟢 تصحيح: تحقق من نوع الرحلة وطباعته للتشخيص
      final isOpenRide =
          rideData['isOpenRide'] == true || rideData['rideType'] == 'open';
      debugPrint(
          'NotificationService: نوع الرحلة: ${isOpenRide ? "مفتوحة" : "عادية"}');

      if (!_initialized) await initialize();

      if (rideData == null) {
        debugPrint('NotificationService: بيانات الرحلة فارغة');
        return;
      }

      // عرض الإشعار
      final androidDetails = AndroidNotificationDetails(
        channelId,
        'رحلات جديدة',
        channelDescription: 'إشعارات الرحلات الجديدة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

      await _notificationsPlugin.show(
        notificationId,
        'رحلة جديدة متاحة',
        'رحلة جديدة من $pickupAddress',
        notificationDetails,
        payload: 'rideId=$rideId&pickup=$pickupAddress',
      );

      debugPrint('NotificationService: تم إرسال إشعار للرحلة $rideId بنجاح');

      // حفظ نوع الرحلة في SharedPreferences للاستخدام لاحقًا
      await SharedPreferencesHelper.setPendingRideType(isOpenRide);

      // فتح شاشة الرحلة تلقائيًا
      await Future.delayed(const Duration(milliseconds: 500));
      _openRideScreen(rideId, rideData);
    } catch (e) {
      debugPrint('NotificationService: خطأ في عرض الإشعار الاختباري - $e');
    }
  }

  // التحقق من توفر السائق
  static Future<bool> _checkDriverAvailability(String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) return false;

      final driverStatus = driverDoc.data()?['status'] as String?;
      final currentRideId = driverDoc.data()?['currentRideId'];

      return (driverStatus != 'busy' && currentRideId == null);
    } catch (e) {
      debugPrint('NotificationService: خطأ في التحقق من حالة السائق - $e');
      return false;
    }
  }

  // أضف دالة عامة لاختبار الإشعارات
  static Future<void> testNotification() async {
    try {
      if (!_initialized) {
        await initialize();
      }

      debugPrint('NotificationService: بدء اختبار الإشعارات');

      // إنشاء إشعار اختباري مع صوت وتنبيه عالي الأولوية
      final androidDetails = AndroidNotificationDetails(
        channelId,
        'رحلات جديدة',
        channelDescription: 'إشعارات الرحلات الجديدة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification.aiff',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      // استخدام رقم عشوائي للتأكد من ظهور الإشعار الجديد
      final int notificationId = DateTime.now().millisecondsSinceEpoch % 10000;

      await _notificationsPlugin.show(
        notificationId,
        'اختبار الإشعارات',
        'هذا إشعار اختباري للتأكد من عمل النظام - ${DateTime.now().toString()}',
        notificationDetails,
        payload:
            'test=notification&time=${DateTime.now().millisecondsSinceEpoch}',
      );

      debugPrint('NotificationService: تم إرسال إشعار الاختبار بنجاح');
      return Future.value(true);
    } catch (e) {
      debugPrint('NotificationService: خطأ في اختبار الإشعارات - $e');
      return Future.error(e);
    }
  }

  // دالة تشخيصية لفحص الاستماع للرحلات
  static Future<void> diagnosticCheckRides() async {
    try {
      debugPrint('NotificationService: بدء الفحص التشخيصي للرحلات...');

      final driverData = await SharedPreferencesHelper.getDriverData();
      final city = driverData['city'];

      if (city == null) {
        debugPrint(
            'NotificationService: لا يمكن إتمام الفحص - المدينة غير محددة');
        return;
      }

      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .get();

      debugPrint(
          'NotificationService: إجمالي الرحلات المعلقة: ${ridesSnapshot.docs.length}');

      final cityRidesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .where('city', isEqualTo: city)
          .get();

      debugPrint(
          'NotificationService: الرحلات المعلقة في مدينة $city: ${cityRidesSnapshot.docs.length}');

      if (cityRidesSnapshot.docs.isEmpty) {
        debugPrint(
            'NotificationService: لا توجد رحلات معلقة في مدينتك. جرب إنشاء رحلة جديدة.');
      } else {
        // قم بعرض إشعار لأول رحلة موجودة للاختبار
        final rideDoc = cityRidesSnapshot.docs.first;
        final rideData = rideDoc.data();

        await showRideNotification(
          rideId: rideDoc.id,
          pickupAddress: rideData['pickupAddress'] ?? 'موقع غير معروف',
          rideData: rideData,
        );

        debugPrint(
            'NotificationService: تم محاولة عرض إشعار اختباري لرحلة موجودة');
      }
    } catch (e) {
      debugPrint('NotificationService: خطأ في الفحص التشخيصي - $e');
    }
  }

  // دالة جديدة لفحص الرحلات المعلقة مباشرة
  static Future<void> checkPendingRidesDirectly() async {
    try {
      debugPrint('NotificationService: فحص مباشر للرحلات المعلقة...');

      if (!_initialized) await initialize();

      final driverData = await SharedPreferencesHelper.getDriverData();
      final city = driverData['city'];

      if (city == null) {
        debugPrint('NotificationService: المدينة غير محددة');
        return;
      }

      // استعلام مباشر بدون قيود كثيرة
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .get();

      debugPrint(
          'NotificationService: عدد الرحلات المعلقة: ${ridesSnapshot.docs.length}');

      // طباعة تفاصيل كل رحلة للتشخيص
      for (var doc in ridesSnapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final rideCity = data['city'];

        debugPrint(
            'NotificationService: رحلة معلقة - معرف: $id، المدينة: $rideCity');
      }

      // فلترة الرحلات حسب المدينة
      final cityRidesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .where('city', isEqualTo: city)
          .get();

      debugPrint(
          'NotificationService: عدد الرحلات في $city: ${cityRidesSnapshot.docs.length}');

      if (cityRidesSnapshot.docs.isNotEmpty) {
        // عرض إشعار لأول رحلة
        final doc = cityRidesSnapshot.docs.first;
        final Map<String, dynamic>? rideData = doc.data();

        if (rideData != null) {
          final pickupAddress =
              rideData['pickupAddress'] as String? ?? 'موقع غير معروف';

          await showTestRideNotification(
            rideId: doc.id,
            pickupAddress: pickupAddress,
            rideData: rideData,
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService: خطأ في فحص الرحلات المعلقة - $e');
    }
  }

  static void stopListening() {
    _ridesSubscription?.cancel();
    _ridesSubscription = null;
    _isListening = false;
    debugPrint('NotificationService: تم إيقاف المراقبة');
  }
}
