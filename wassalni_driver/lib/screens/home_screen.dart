import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/screens/open_ride_screen_v2.dart';
import 'package:rimapp_driver/screens/profile_screen.dart';
import 'package:rimapp_driver/services/alert_service.dart';
import 'package:rimapp_driver/services/location_service.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import 'package:rimapp_driver/utils/custom_widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/map_style.dart';
import 'login_screen.dart';
import 'completed_rides_screen.dart';
import 'transactions_screen.dart';
import '../services/notification_service.dart';
import 'available_rides_screen.dart';
import 'ride_screen_new_version.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late GoogleMapController _mapController;
  Position? _currentPosition;
  bool _isOnline = false;
  String _balance = "0";
  String _driverId = "";
  Timer? _locationTimer;
  final Set<Marker> _markers = {};
  late BitmapDescriptor _driverIcon;
  String? _currentRideId;
  Map<String, dynamic>? _currentRideData;
  bool _hasActiveRide = false;
  String _driverName = "";
  String _driverPhone = "";

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _initDriverIcon();
    _checkPermissions();
    _loadDriverData();
    _checkCurrentRide();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _updateLocation(),
    );
    // Set context for notification service (handles both admin open rides and customer rides)
    NotificationService.setContext(context);
    NotificationService.initialize();
    NotificationService.listenForNewRides();

    _checkPendingRides();
  }

  Future<void> _initializeServices() async {
    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      if (driverData['driverId'] != null) {
        await LocationService.startTracking();

        await NotificationService.listenForNewRides();
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initDriverIcon() async {
    try {
      final markerIcon = await _createCustomDriverMarker();
      setState(() {
        _driverIcon = markerIcon;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل أيقونة السائق: $e');
      _driverIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  Future<BitmapDescriptor> _createCustomDriverMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = 120.0;
    final center = Offset(size / 2, size / 2);

    // Draw outer glow/shadow
    final glowPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 42, glowPaint);

    // Draw white background circle
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 38, bgPaint);

    // Draw gradient circle
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - 35, center.dy - 35),
        Offset(center.dx + 35, center.dy + 35),
        [AppColors.primary, AppColors.primaryLight],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 35, gradientPaint);

    // Draw car icon
    final carPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Car body
    final carPath = Path();
    // Main body
    carPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 40, height: 24),
      const Radius.circular(4),
    ));
    // Roof
    carPath.addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 6),
        width: 24,
        height: 12,
      ),
      const Radius.circular(3),
    ));
    canvas.drawPath(carPath, carPaint);

    // Draw wheels
    final wheelPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy + 10), 4, wheelPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy + 10), 4, wheelPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, 35, borderPaint);

    // Draw direction indicator (small triangle at top)
    final trianglePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    final trianglePath = Path();
    trianglePath.moveTo(center.dx, center.dy - 50);
    trianglePath.lineTo(center.dx - 8, center.dy - 38);
    trianglePath.lineTo(center.dx + 8, center.dy - 38);
    trianglePath.close();
    canvas.drawPath(trianglePath, trianglePaint);

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadDriverData() async {
    final driverData = await SharedPreferencesHelper.getDriverData();
    if (driverData['driverId'] != null) {
      _driverId = driverData['driverId']!;
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_driverId)
          .get();

      if (driverDoc.exists) {
        setState(() {
          _balance = driverDoc.data()?['balance']?.toString() ?? "0";
          _isOnline = driverDoc.data()?['status'] == 'online';
          _driverName = driverDoc.data()?['name'] ?? "";
          _driverPhone = driverDoc.data()?['phone'] ?? "";
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location service is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('خدمة الموقع معطلة', textAlign: TextAlign.right),
            content: const Text(
              'يجب تفعيل خدمة الموقع لاستخدام التطبيق. هل تريد فتح الإعدادات؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await Geolocator.openLocationSettings();
        }
      }
      return;
    }

    // Check permission status
    permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم رفض إذن الموقع'),
              action: SnackBarAction(
                label: 'إعادة المحاولة',
                onPressed: _getCurrentLocation,
              ),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إذن الموقع مطلوب', textAlign: TextAlign.right),
            content: const Text(
              'تم رفض إذن الموقع بشكل دائم. يجب تفعيله من إعدادات التطبيق لاستخدام الخريطة.',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await Geolocator.openAppSettings();
        }
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      _updateDriverMarker(position);

      if (_mapController != null) {
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 16,
              tilt: 45,
            ),
          ),
        );
      }

      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في تحديد الموقع')),
      );
    }
  }

  void _updateDriverMarker(Position position) {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('driverLocation'),
        position: LatLng(position.latitude, position.longitude),
        icon: _driverIcon,
        rotation: position.heading,
        flat: true,
        anchor: const Offset(0.5, 0.5),
        infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        zIndex: 2,
      ),
    );
    setState(() {});
  }

  Future<void> _updateLocation() async {
    if (_isOnline) {
      try {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        _updateDriverMarker(position);
        setState(() {
          _currentPosition = position;
        });

        if (_driverId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(_driverId)
              .update({
            'location': GeoPoint(position.latitude, position.longitude),
            'heading': position.heading,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Error updating location: $e');
      }
    }
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() {
      _isOnline = !_isOnline;
    });

    if (_driverId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_driverId)
          .update({
        'status': _isOnline ? 'online' : 'offline',
      });
    }
  }

  Future<void> _updateDriverStatus(bool isOnline) async {
    if (_driverId.isNotEmpty) {
      try {
        if (isOnline) {
          // التحقق من رصيد السائق
          final driverDoc = await FirebaseFirestore.instance
              .collection('drivers')
              .doc(_driverId)
              .get();

          final double balance = double.tryParse(
                  driverDoc.data()?['balance']?.toString() ?? '0') ??
              0;
          if (balance <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'يجب شحن رصيدك لتتمكن من استقبال المشاوير. الرجاء الإتصال بالدعم'),
                  duration: Duration(seconds: 5),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          final status = await Permission.notification.request();
          if (status.isDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'يجب السماح بالإشعارات لتلقي التنبيهات عن الرحلات الجديدة'),
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }

        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(_driverId)
            .update({
          'status': isOnline ? 'online' : 'offline',
        });

        setState(() {
          _isOnline = isOnline;
        });

        if (isOnline) {
          _updateLocation();
          await NotificationService.initialize();
          await AlertService.initialize();
          await NotificationService.listenForNewRides();
        } else {
          NotificationService.stopListening();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isOnline ? 'أنت الآن متصل' : 'أنت الآن غير متصل'),
              backgroundColor: isOnline ? Colors.green : Colors.grey,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating driver status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حدث خطأ ما، الرجاء المحاولة مرة أخرى'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج', textAlign: TextAlign.right),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              try {
                if (_isOnline) {
                  await _updateDriverStatus(false);
                }
                LocationService.stopTracking();
                await SharedPreferencesHelper.clearDriverData();

                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                debugPrint('Error during logout: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج')),
                  );
                }
              }
            },
            child: const Text('تأكيد'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: _isOnline
            ? AppColors.primaryGradient
            : LinearGradient(
                colors: [AppColors.textSecondary, AppColors.textHint],
              ),
        borderRadius: BorderRadius.circular(AppRadius.round),
        boxShadow: [
          BoxShadow(
            color: (_isOnline ? AppColors.primary : AppColors.textSecondary)
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.round),
          onTap: () => _updateDriverStatus(!_isOnline),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOnline ? Icons.check_circle : Icons.cancel,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isOnline ? 'متصل' : 'غير متصل',
                style: AppTextStyles.arabicBody.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkPendingRides() async {
    try {
      final pendingRideId = await SharedPreferencesHelper.getPendingRideId();

      if (pendingRideId != null && pendingRideId.isNotEmpty) {
        debugPrint('تم العثور على رحلة معلقة: $pendingRideId');

        final rideDoc = await FirebaseFirestore.instance
            .collection('rides')
            .doc(pendingRideId)
            .get();

        if (rideDoc.exists && rideDoc.data()?['status'] == 'pending') {
          await SharedPreferencesHelper.clearPendingRideId();

          if (mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RideScreenNewVersion(
                  key: UniqueKey(),
                  rideData: rideDoc.data()!,
                  rideId: pendingRideId,
                ),
              ),
            );
          }
        } else {
          await SharedPreferencesHelper.clearPendingRideId();
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من الرحلات المعلقة: $e');
    }
  }

  void _searchForRides() async {
    final driverId = await SharedPreferencesHelper.getUserId();
    if (driverId == null) return;

    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final driverStatus = driverDoc.data()?['status'];
        final currentRideId = driverDoc.data()?['currentRideId'];

        if (driverStatus == 'busy' ||
            (currentRideId != null && currentRideId.isNotEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('لا يمكن البحث عن رحلات جديدة أثناء وجود رحلة نشطة'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('خطأ في التحقق من حالة السائق: $e');
    }
  }

  Future<void> _checkCurrentRide() async {
    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];

      if (driverId == null) return;

      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        final currentRideId = driverDoc.data()?['currentRideId'];

        if (currentRideId != null && currentRideId.isNotEmpty) {
          final rideDoc = await FirebaseFirestore.instance
              .collection('rides')
              .doc(currentRideId)
              .get();

          if (rideDoc.exists) {
            setState(() {
              _currentRideId = currentRideId;
              _currentRideData = rideDoc.data();
              _hasActiveRide = true;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في فحص الرحلة الحالية: $e');
    }
  }

  void _navigateToCurrentRide() async {
    if (_currentRideId == null) {
      await _checkCurrentRide();

      if (_currentRideId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد رحلة حالية')),
        );
        return;
      }
    }

    final isOpenRide = _currentRideData?['isOpenRide'] == true;

    if (isOpenRide) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OpenRideScreenV2(
            rideData: _currentRideData ?? {},
            rideId: _currentRideId!,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RideScreenNewVersion(
            rideData: _currentRideData ?? {},
            rideId: _currentRideId!,
          ),
        ),
      );
    }
  }

  Future<void> _checkPermissions() async {
    await _getCurrentLocation();

    if (Platform.isAndroid) {
      bool hasOverlayPermission = await Permission.systemAlertWindow.isGranted;

      if (!hasOverlayPermission) {
        bool showRationale =
            await Permission.systemAlertWindow.shouldShowRequestRationale;

        if (showRationale) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('إذن مطلوب', textAlign: TextAlign.right),
              content: const Text(
                'يحتاج التطبيق إلى إذن "الظهور فوق التطبيقات الأخرى" لعرض الخريطة بشكل صحيح في بعض الأجهزة. يرجى السماح بهذا الإذن من إعدادات التطبيق.',
                textAlign: TextAlign.right,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('لاحقاً'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Permission.systemAlertWindow.request();
                  },
                  child: const Text('طلب الإذن'),
                ),
              ],
            ),
          );
        } else {
          await Permission.systemAlertWindow.request();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(18.0735, -15.9582),
              zoom: 15,
            ),
            onMapCreated: (GoogleMapController controller) async {
              _mapController = controller;

              await Future.delayed(const Duration(milliseconds: 500));

              try {
                if (Platform.isAndroid) {
                  try {
                    await controller.setMapStyle("[]");
                    await Future.delayed(const Duration(milliseconds: 200));
                  } catch (e) {
                    debugPrint('خطأ في إعادة ضبط نمط الخريطة: $e');
                  }
                }

                await controller.setMapStyle(MapStyle.mapStyle);

                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('خطأ في تهيئة الخريطة: $e');

                try {
                  const simpleMapStyle = '[]';
                  await controller.setMapStyle(simpleMapStyle);
                } catch (e2) {
                  debugPrint('فشلت محاولة استخدام نمط خريطة بسيط: $e2');
                }
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            markers: _markers,
            mapType: MapType.normal,
            compassEnabled: true,
          ),
          Positioned(
            top: paddingTop + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Modern Drawer button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.menu_rounded, color: AppColors.primary, size: 26),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
                // Modern Balance display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppColors.secondaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '$_balance MRU',
                        style: AppTextStyles.arabicBody.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status switch (left side for RTL)
                _buildStatusSwitch(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _getCurrentLocation,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.my_location, size: 28),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: AppColors.heroGradient,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.3),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_rounded, size: 35, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _driverName,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isOnline 
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isOnline ? AppColors.success : AppColors.error,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? AppColors.success : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'متصل' : 'غير متصل',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.history_rounded,
              title: 'المشاوير',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CompletedRidesScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.receipt_long_rounded,
              title: 'المعاملات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionsScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.person_rounded,
              title: 'الملف الشخصي',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.settings_rounded,
              title: 'الإعدادات',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.logout_rounded,
              title: 'تسجيل الخروج',
              onTap: () {
                Navigator.pop(context);
                _logout();
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isDestructive
                        ? LinearGradient(
                            colors: [
                              AppColors.error.withOpacity(0.1),
                              AppColors.error.withOpacity(0.05),
                            ],
                          )
                        : AppColors.primaryGradient.scale(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isDestructive ? AppColors.error : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.arabicBody.copyWith(
                      color: isDestructive ? AppColors.error : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_rounded,
                  size: 16,
                  color: isDestructive ? AppColors.error : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
