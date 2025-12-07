import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dotted_line/dotted_line.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/map_style.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';
import 'package:audioplayers/audioplayers.dart';

// إضافة نموذج لإدارة حالة الرحلة بشكل أفضل
class RideState {
  bool isLoading;
  bool isAccepted;
  bool isRideStarted;
  bool isRideCompleted;
  bool isPaused;
  String? customerPhone;
  String? customerName;
  Position? currentPosition;
  LatLng? pickupLocation;
  int elapsedSeconds;
  double totalDistanceMeters;
  double currentSpeed;
  double currentDistance;
  double farePerKm;
  Timestamp? pauseStartTime;
  int totalPausedSeconds;

  RideState({
    this.isLoading = false,
    this.isAccepted = false,
    this.isRideStarted = false,
    this.isRideCompleted = false,
    this.isPaused = false,
    this.customerPhone,
    this.customerName,
    this.currentPosition,
    this.pickupLocation,
    this.elapsedSeconds = 0,
    this.totalDistanceMeters = 0,
    this.currentSpeed = 0,
    this.currentDistance = 0.0,
    this.farePerKm = 50,
    this.pauseStartTime,
    this.totalPausedSeconds = 0,
  });

  // إنشاء نسخة جديدة من الحالة مع تحديث بعض القيم
  RideState copyWith({
    bool? isLoading,
    bool? isAccepted,
    bool? isRideStarted,
    bool? isRideCompleted,
    bool? isPaused,
    String? customerPhone,
    String? customerName,
    Position? currentPosition,
    LatLng? pickupLocation,
    int? elapsedSeconds,
    double? totalDistanceMeters,
    double? currentSpeed,
    double? currentDistance,
    double? farePerKm,
    Timestamp? pauseStartTime,
    int? totalPausedSeconds,
  }) {
    return RideState(
      isLoading: isLoading ?? this.isLoading,
      isAccepted: isAccepted ?? this.isAccepted,
      isRideStarted: isRideStarted ?? this.isRideStarted,
      isRideCompleted: isRideCompleted ?? this.isRideCompleted,
      isPaused: isPaused ?? this.isPaused,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      currentPosition: currentPosition ?? this.currentPosition,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentDistance: currentDistance ?? this.currentDistance,
      farePerKm: farePerKm ?? this.farePerKm,
      pauseStartTime: pauseStartTime ?? this.pauseStartTime,
      totalPausedSeconds: totalPausedSeconds ?? this.totalPausedSeconds,
    );
  }
}

class OpenRideScreenV2 extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const OpenRideScreenV2({
    Key? key,
    required this.rideData,
    required this.rideId,
  }) : super(key: key);

  @override
  State<OpenRideScreenV2> createState() => _OpenRideScreenV2State();
}

class _OpenRideScreenV2State extends State<OpenRideScreenV2> {
  // استخدام كائن RideState لإدارة حالة الرحلة بشكل أفضل
  late RideState _rideState;

  Timer? _locationTimer;
  Timer? _timeTimer;
  Timer? _distanceTimer;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  final TextEditingController _fareController = TextEditingController();
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔵 [LOGGING] =========> OpenRideScreenV2 تم تحميلها! ${DateTime.now()} <=========');

    debugPrint('🔵 [LOGGING] OpenRideScreenV2: Ride ID: ${widget.rideId}');
    debugPrint('🔵 [LOGGING] OpenRideScreenV2: Ride data: ${widget.rideData}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: Ride status: ${widget.rideData['status']}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: Pickup address: ${widget.rideData['pickupAddress']}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: Customer ID: ${widget.rideData['customerId']}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: isOpenRide: ${widget.rideData['isOpenRide']}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: rideType: ${widget.rideData['rideType']}');
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: Assigned driver ID: ${widget.rideData['assignedDriverId']}');

    // تهيئة حالة الرحلة
    _rideState = RideState();

    _initializeData();
    _startLocationTracking();
    _startTimeTracking();
    _listenToRideUpdates();
    _initializeAudioPlayer();
    _getPickupLocation();
    _getCustomerInfo();
    _getFareSettings();

    // فحص إذا كان رقم الهاتف موجود في بيانات الرحلة مباشرة
    if (widget.rideData.containsKey('customerPhone')) {
      debugPrint(
          '🔵 [LOGGING] OpenRideScreenV2: Customer phone found in ride data');
      setState(() {
        _rideState = _rideState.copyWith(
            customerPhone: widget.rideData['customerPhone']);
      });
    }

    // التحقق من حالة الرحلة والتعيين المناسب
    final status = widget.rideData['status'];
    debugPrint(
        '🔵 [LOGGING] OpenRideScreenV2: Processing ride status: $status');

    if (status == 'accepted') {
      debugPrint('🔵 [LOGGING] OpenRideScreenV2: Setting ride as accepted');
      setState(() {
        _rideState = _rideState.copyWith(isAccepted: true);
      });
    } else if (status == 'started') {
      debugPrint('🔵 [LOGGING] OpenRideScreenV2: Setting ride as started');
      setState(() {
        _rideState = _rideState.copyWith(isAccepted: true, isRideStarted: true);
      });
      _startDistanceTracking();
    } else if (status == 'completed') {
      debugPrint('🔵 [LOGGING] OpenRideScreenV2: Setting ride as completed');
      setState(() {
        _rideState = _rideState.copyWith(
            isAccepted: true, isRideStarted: true, isRideCompleted: true);
      });
    }
  }

  Future<void> _initializeData() async {
    // التحقق من وجود بيانات الرحلة
    if (widget.rideData.isEmpty && widget.rideId.isNotEmpty) {
      try {
        final rideDoc = await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .get();

        if (rideDoc.exists) {
          final data = rideDoc.data()!;
          // استكمال البيانات المفقودة
          if (data.containsKey('customerId')) {
            final customerDoc = await FirebaseFirestore.instance
                .collection('customers')
                .doc(data['customerId'])
                .get();

            if (customerDoc.exists) {
              setState(() {
                _rideState = _rideState.copyWith(
                    customerPhone: customerDoc.data()?['phone']);
              });
            }
          }

          // تحديد موقع الانطلاق
          if (data.containsKey('pickupLocation')) {
            final pickup = data['pickupLocation'] as GeoPoint;
            setState(() {
              _rideState = _rideState.copyWith(
                  pickupLocation: LatLng(
                pickup.latitude,
                pickup.longitude,
              ));
            });
          }

          // استرجاع زمن البدء والمسافة المقطوعة إذا كانت موجودة
          if (data.containsKey('elapsedSeconds')) {
            setState(() {
              _rideState = _rideState.copyWith(
                  elapsedSeconds: data['elapsedSeconds'] ?? 0);
            });
          }

          if (data.containsKey('totalDistanceMeters')) {
            setState(() {
              _rideState = _rideState.copyWith(
                  totalDistanceMeters:
                      data['totalDistanceMeters']?.toDouble() ?? 0);
            });
          }

          // تحديد حالة الرحلة
          setState(() {
            _rideState = _rideState.copyWith(
                isPaused: data['status'] == 'paused',
                pauseStartTime: data['status'] == 'paused' &&
                        data.containsKey('pauseStartTime')
                    ? data['pauseStartTime'] as Timestamp?
                    : null,
                totalPausedSeconds: data.containsKey('totalPausedSeconds')
                    ? data['totalPausedSeconds'] ?? 0
                    : 0);
          });
        }
      } catch (e) {
        debugPrint('خطأ في استرجاع بيانات الرحلة: $e');
      }
    }
  }

  void _listenToRideUpdates() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          // تحديث حالة الرحلة حسب التغييرات في قاعدة البيانات
          _rideState = _rideState.copyWith(
              isPaused: data['status'] == 'paused',
              pauseStartTime: data['status'] == 'paused' &&
                      data.containsKey('pauseStartTime')
                  ? data['pauseStartTime'] as Timestamp?
                  : _rideState.pauseStartTime,
              totalPausedSeconds: data.containsKey('totalPausedSeconds')
                  ? data['totalPausedSeconds'] ?? _rideState.totalPausedSeconds
                  : _rideState.totalPausedSeconds);
        });
      }
    });
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_rideState.isPaused) return;

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (_rideState.currentPosition != null) {
          // حساب المسافة المقطوعة منذ آخر تحديث
          double distanceInMeters = Geolocator.distanceBetween(
            _rideState.currentPosition!.latitude,
            _rideState.currentPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distanceInMeters > 5) {
            // تجاهل التغيرات الصغيرة
            setState(() {
              _rideState = _rideState.copyWith(
                  totalDistanceMeters:
                      _rideState.totalDistanceMeters + distanceInMeters,
                  currentSpeed: position.speed // السرعة بالمتر/ثانية
                  );
            });

            // تحديث المسار على الخريطة
            _updatePolyline(position);

            // تحديث بيانات الرحلة في قاعدة البيانات
            _updateRideData();
          }
        }

        setState(() {
          _rideState = _rideState.copyWith(currentPosition: position);
        });

        // تحريك الخريطة لتتبع الموقع الحالي
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      } catch (e) {
        debugPrint('خطأ في تتبع الموقع: $e');
      }
    });
  }

  void _updatePolyline(Position newPosition) {
    if (_rideState.currentPosition == null) {
      _rideState = _rideState.copyWith(currentPosition: newPosition);
      return;
    }

    final List<LatLng> points = [
      LatLng(_rideState.currentPosition!.latitude,
          _rideState.currentPosition!.longitude),
      LatLng(newPosition.latitude, newPosition.longitude),
    ];

    final polylineId =
        PolylineId('route_${DateTime.now().millisecondsSinceEpoch}');

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: polylineId,
          color: const Color(0xFF2E3F51),
          width: 5,
          points: points,
        ),
      );
      _rideState = _rideState.copyWith(currentPosition: newPosition);
    });

    // تحريك الكاميرا إلى الموقع الجديد
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
          LatLng(newPosition.latitude, newPosition.longitude)),
    );

    // تحديث بيانات الرحلة في Firestore
    _updateRideData();
  }

  void _startTimeTracking() {
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_rideState.isPaused) return;
      setState(() {
        _rideState =
            _rideState.copyWith(elapsedSeconds: _rideState.elapsedSeconds + 1);
      });
    });
  }

  Future<void> _updateRideData() async {
    if (widget.rideId.isEmpty || _rideState.currentPosition == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'elapsedSeconds': _rideState.elapsedSeconds,
        'totalDistanceMeters': _rideState.totalDistanceMeters,
        'lastLocation': GeoPoint(_rideState.currentPosition!.latitude,
            _rideState.currentPosition!.longitude),
        'lastUpdateTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('خطأ في تحديث بيانات الرحلة: $e');
    }
  }

  Future<void> _pauseOrResumeRide() async {
    setState(() => _rideState = _rideState.copyWith(isLoading: true));
    try {
      if (_rideState.isPaused) {
        // احتساب الوقت المتوقف
        if (_rideState.pauseStartTime != null) {
          final pauseEnd = DateTime.now();
          final pauseStart = _rideState.pauseStartTime!.toDate();
          final pauseDuration = pauseEnd.difference(pauseStart).inSeconds;
          _rideState = _rideState.copyWith(
              totalPausedSeconds:
                  _rideState.totalPausedSeconds + pauseDuration);
        }

        // استئناف الرحلة
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({
          'status': 'in_progress',
          'totalPausedSeconds': _rideState.totalPausedSeconds,
          'pauseStartTime': null,
        });
      } else {
        // إيقاف الرحلة مؤقتًا
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({
          'status': 'paused',
          'pauseStartTime': FieldValue.serverTimestamp(),
        });
      }

      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    } catch (e) {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  Future<void> _completeRide() async {
    if (_rideState.isLoading) return;

    // حساب السعر النهائي تلقائيًا بناءً على المسافة
    final calculatedFare =
        (_rideState.currentDistance * _rideState.farePerKm).round();

    // تأكيد إكمال الرحلة
    final shouldComplete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إكمال الرحلة', textAlign: TextAlign.right),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'هل أنت متأكد من إكمال هذه الرحلة؟',
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),
                Text(
                  'السعر النهائي: $calculatedFare MRU',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('تراجع'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('إكمال الرحلة'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldComplete) return;

    setState(() => _rideState = _rideState.copyWith(isLoading: true));

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];

      if (driverId == null) {
        throw Exception('لم يتم العثور على معلومات السائق');
      }

      // استخدام السعر المحسوب تلقائيًا
      final fareAmount = calculatedFare;

      // الحصول على نسبة الاقتطاع
      final pricesDoc = await FirebaseFirestore.instance
          .collection('prices')
          .doc('default')
          .get();

      int feePercentage = 10; // القيمة الافتراضية
      if (pricesDoc.exists && pricesDoc.data()!.containsKey('feePercentage')) {
        var percentValue = pricesDoc.data()!['feePercentage'];
        if (percentValue is double) {
          feePercentage = percentValue.toInt();
        } else if (percentValue is int) {
          feePercentage = percentValue;
        } else if (percentValue is String) {
          feePercentage = int.parse(percentValue);
        }
      }

      // حساب مبلغ العمولة
      int serviceFee = ((fareAmount * feePercentage) / 100).toInt();
      int driverAmount = fareAmount - serviceFee;

      // تحديث حالة الرحلة
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'fare': fareAmount,
        'distance': _rideState.currentDistance,
        'serviceFee': serviceFee,
        'driverAmount': driverAmount,
      });

      // إنشاء معاملة للخصم
      final transactionData = {
        'amount': serviceFee,
        'type': 'fee',
        'description': 'خصم عمولة الإدارة للرحلة #${widget.rideId}',
        'rideId': widget.rideId,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // خصم العمولة من رصيد السائق
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'balance': FieldValue.increment(-serviceFee),
        'currentRideId': null,
        'status': 'available',
        'completedRides': FieldValue.arrayUnion([widget.rideId]),
        'transactions': FieldValue.arrayUnion([transactionData]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إكمال الرحلة بنجاح. تم خصم عمولة $serviceFee MRU'),
          backgroundColor: Colors.green,
        ),
      );

      // العودة للشاشة الرئيسية
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    }
  }

  void _callCustomer() async {
    if (_rideState.customerPhone == null) return;

    final phoneUrl = 'tel:${_rideState.customerPhone}';
    if (await canLaunchUrl(Uri.parse(phoneUrl))) {
      await launchUrl(Uri.parse(phoneUrl));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن الاتصال بالرقم')),
        );
      }
    }
  }

  String _formatTime(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;

    final String hoursStr =
        hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = remainingSeconds.toString().padLeft(2, '0');

    return '$hoursStr$minutesStr:$secondsStr';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} م';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)} كم';
    }
  }

  String _formatSpeed(double speedInMetersPerSecond) {
    // تحويل من م/ث إلى كم/س
    final speedInKmh = speedInMetersPerSecond * 3.6;
    return '${speedInKmh.toStringAsFixed(1)} كم/س';
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _timeTimer?.cancel();
    _rideSubscription?.cancel();
    _mapController?.dispose();
    _fareController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Map
          _buildMapLayer(),

          // 2. Modern Gradient Top Bar
          _buildTopBarLayer(),

          // 3. Floating Status Badge
          _buildStatusBadge(),

          // 4. Bottom Controls Sheet
          _buildBottomControls(),

          // 5. Loading Overlay
          if (_rideState.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _rideState.pickupLocation ?? const LatLng(18.08, -15.97),
        zoom: 15,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false, // Custom button used
      zoomControlsEnabled: false,
      onMapCreated: (GoogleMapController controller) async {
        _mapController = controller;
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          if (Platform.isAndroid) {
            try {
              await controller.setMapStyle("[]");
              await Future.delayed(const Duration(milliseconds: 200));
            } catch (e) {
              debugPrint('Map style reset error: $e');
            }
          }
          await controller.setMapStyle(MapStyle.mapStyle);
          setState(() {});
        } catch (e) {
          debugPrint('Map init error: $e');
        }
      },
    );
  }

  Widget _buildTopBarLayer() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            // Back Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Spacer(),
            // Title
            Text(
              'رحلة مفتوحة',
              style: AppTextStyles.arabicTitle.copyWith(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Call Button (if applicable)
            if (_rideState.customerPhone != null)
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.phone_rounded,
                      color: Colors.white, size: 20),
                  onPressed: _callCustomer,
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'عداد مباشر',
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Metrics Row
                if (_rideState.isRideStarted && !_rideState.isRideCompleted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricItem(
                          'المسافة',
                          '${_rideState.currentDistance.toStringAsFixed(2)}',
                          'كم',
                          Icons.place_rounded,
                          AppColors.info,
                        ),
                        Container(
                            width: 1, height: 40, color: AppColors.divider),
                        _buildMetricItem(
                          'الوقت',
                          _formatDuration(_rideState.elapsedSeconds),
                          '',
                          Icons.timer_rounded,
                          AppColors.warning,
                        ),
                        Container(
                            width: 1, height: 40, color: AppColors.divider),
                        _buildMetricItem(
                          'التكلفة',
                          '${(_rideState.currentDistance * _rideState.farePerKm).round()}',
                          'MRU',
                          Icons.attach_money_rounded,
                          AppColors.success,
                        ),
                      ],
                    ),
                  ),

                // 2. Customer Info (if needed)
                if (_rideState.customerPhone != null && !_rideState.isRideStarted)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.person_rounded,
                              color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _rideState.customerName ?? 'زبون',
                                style: AppTextStyles.arabicTitle.copyWith(
                                    fontSize: 16),
                              ),
                              Text(
                                _rideState.customerPhone ?? '',
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, String unit,
      IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.arabicBodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTextStyles.arabicDisplayMedium.copyWith(
                  fontSize: 24,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // إعادة استخدام دالة الأزرار مع تحديث التصميم
  Widget _buildActionButtons() {
    if (_rideState.isRideCompleted) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.successGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'العودة للشاشة الرئيسية',
                style: AppTextStyles.arabicTitle.copyWith(
                    color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else if (_rideState.isRideStarted) {
      return Row(
        children: [
          // Pause/Resume Button
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _rideState.isPaused
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _rideState.isPaused
                      ? AppColors.primary
                      : AppColors.warning,
                ),
              ),
              child: TextButton(
                onPressed:
                    _rideState.isLoading ? null : _pauseOrResumeRide,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _rideState.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: _rideState.isPaused
                          ? AppColors.primary
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _rideState.isPaused ? 'استئناف' : 'إيقاف مؤقت',
                      style: AppTextStyles.arabicBody.copyWith(
                        color: _rideState.isPaused
                            ? AppColors.primary
                            : AppColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Finish Button
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _rideState.isLoading ? null : _completeRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.flag_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'إنهاء الرحلة',
                      style: AppTextStyles.arabicTitle.copyWith(
                          color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_rideState.isAccepted) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _rideState.isLoading ? null : _beginRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_filled_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'بدء الرحلة',
                    style: AppTextStyles.arabicTitle.copyWith(
                        color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _rideState.isLoading ? null : _cancelRide,
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            label: Text(
              'إلغاء الرحلة',
              style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              backgroundColor: AppColors.error.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: _rideState.isLoading
                  ? null
                  : () => _rejectRide('رفض السائق'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.surfaceVariant,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'رفض',
                style: AppTextStyles.arabicTitle.copyWith(
                    color: AppColors.textPrimary, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _rideState.isLoading ? null : _acceptRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'قبول الرحلة',
                  style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  // الدوال المساعدة التي لم تتغير تبقى كما هي في الكلاس...


  Future<void> _initializeAudioPlayer() async {
    _audioPlayer = AudioPlayer();
  }

  Future<void> _getPickupLocation() async {
    if (widget.rideData.containsKey('pickupLocation')) {
      final pickupLocation = widget.rideData['pickupLocation'] as GeoPoint;
      setState(() {
        _rideState = _rideState.copyWith(
            pickupLocation: LatLng(
          pickupLocation.latitude,
          pickupLocation.longitude,
        ));
      });

      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _rideState.pickupLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'موقع الانطلاق',
            snippet: widget.rideData['pickupAddress'] ?? '',
          ),
        ),
      );
    }
  }

  Future<void> _getCustomerInfo() async {
    // نحاول الحصول على معلومات الزبون بغض النظر عن حالة الرحلة
    if (widget.rideData.containsKey('customerId')) {
      try {
        final customerDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.rideData['customerId'])
            .get();

        if (customerDoc.exists) {
          setState(() {
            _rideState = _rideState.copyWith(
              customerPhone: customerDoc.data()?['phone'],
              customerName: customerDoc.data()?['name'],
            );
          });
        }
      } catch (e) {
        debugPrint('خطأ في جلب بيانات الزبون: $e');
      }
    }

    // إذا كان رقم الهاتف موجود في بيانات الرحلة مباشرة
    if (widget.rideData.containsKey('customerPhone') &&
        widget.rideData['customerPhone'] != null) {
      setState(() {
        _rideState = _rideState.copyWith(
            customerPhone: widget.rideData['customerPhone']);
      });
    }

    // إذا كان اسم الزبون موجود في بيانات الرحلة مباشرة
    if (widget.rideData.containsKey('customerName') &&
        widget.rideData['customerName'] != null) {
      setState(() {
        _rideState =
            _rideState.copyWith(customerName: widget.rideData['customerName']);
      });
    }
  }

  Future<void> _getFareSettings() async {
    try {
      final pricesDoc = await FirebaseFirestore.instance
          .collection('prices')
          .doc('default')
          .get();

      if (pricesDoc.exists && pricesDoc.data()!.containsKey('farePerKm')) {
        final farePerKm = pricesDoc.data()!['farePerKm'];
        if (farePerKm is num) {
          setState(() {
            _rideState = _rideState.copyWith(farePerKm: farePerKm.toDouble());
          });
        }
      }
    } catch (e) {
      debugPrint('خطأ في جلب إعدادات السعر: $e');
    }
  }

  void _startDistanceTracking() {
    _getCurrentLocation();

    // تحديث المسافة كل 15 ثانية
    _distanceTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateDistance();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _rideState = _rideState.copyWith(currentPosition: position);
      });

      // تحديث موقع السائق على الخريطة
      _updateDriverMarker();

      // توجيه الكاميرا للموقع الحالي
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      debugPrint('خطأ في الحصول على الموقع الحالي: $e');
    }
  }

  void _updateDriverMarker() {
    if (_rideState.currentPosition != null) {
      final driverLocation = LatLng(
        _rideState.currentPosition!.latitude,
        _rideState.currentPosition!.longitude,
      );

      // إزالة علامة السائق السابقة إن وجدت
      _markers.removeWhere((marker) => marker.markerId.value == 'driver');

      // إضافة علامة جديدة للسائق
      _markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        ),
      );

      setState(() {});
    }
  }

  Future<void> _updateDistance() async {
    if (_rideState.currentPosition != null &&
        _rideState.pickupLocation != null &&
        _rideState.isRideStarted) {
      try {
        // حساب المسافة من نقطة الانطلاق
        final distanceInMeters = Geolocator.distanceBetween(
          _rideState.pickupLocation!.latitude,
          _rideState.pickupLocation!.longitude,
          _rideState.currentPosition!.latitude,
          _rideState.currentPosition!.longitude,
        );

        // تحويل المسافة إلى كيلومترات
        final distanceInKm = distanceInMeters / 1000;

        setState(() {
          _rideState = _rideState.copyWith(currentDistance: distanceInKm);
          // تحديث السعر المقترح في حقل النص
          _fareController.text =
              (_rideState.currentDistance * _rideState.farePerKm)
                  .round()
                  .toString();
        });

        // تحديث الموقع الحالي
        _getCurrentLocation();
      } catch (e) {
        debugPrint('خطأ في تحديث المسافة: $e');
      }
    }
  }

  Future<void> _beginRide() async {
    if (_rideState.isLoading) return;
    setState(() => _rideState = _rideState.copyWith(isLoading: true));

    try {
      final driverId = await SharedPreferencesHelper.getUserId();

      if (driverId == null) {
        throw Exception('معرّف السائق غير متوفر');
      }

      // التحقق من حالة السائق (هل هو متاح؟)
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) {
        throw Exception('بيانات السائق غير متوفرة');
      }

      // التحقق من أن السائق لا يعمل على رحلة أخرى
      final currentRideId = driverDoc.data()?['currentRideId'];
      if (currentRideId != null &&
          currentRideId.isNotEmpty &&
          currentRideId != widget.rideId) {
        throw Exception('لا يمكن بدء هذه الرحلة لأنك مشغول في رحلة أخرى');
      }

      // استخدام Transaction للتحقق من حالة الرحلة وتحديثها
      bool rideStarted = await FirebaseFirestore.instance
          .runTransaction<bool>((transaction) async {
        // جلب أحدث بيانات الرحلة
        final freshRideDoc = await transaction.get(
            FirebaseFirestore.instance.collection('rides').doc(widget.rideId));

        if (!freshRideDoc.exists) {
          return false; // الرحلة غير موجودة
        }

        final rideData = freshRideDoc.data()!;

        // التحقق من أن الرحلة تم قبولها ولم تبدأ بعد
        if (rideData['status'] != 'accepted') {
          return false;
        }

        // التحقق من أن السائق الحالي هو من قبل الرحلة
        if (rideData['driverId'] != driverId) {
          return false;
        }

        // تحديث حالة الرحلة
        transaction.update(
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId),
          {
            'status': 'started',
            'startTime': FieldValue.serverTimestamp(),
          },
        );

        return true;
      });

      if (!rideStarted) {
        throw Exception('تعذر بدء الرحلة - تحقق من حالة الرحلة');
      }

      // تفعيل تتبع المسافة
      setState(() {
        _rideState = _rideState.copyWith(
          isRideStarted: true,
        );
      });

      _startDistanceTracking();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم بدء الرحلة، يتم الآن حساب المسافة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    }
  }

  Future<void> _cancelRide() async {
    if (_rideState.isLoading) return;

    final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('إلغاء الرحلة', textAlign: TextAlign.right),
            content: const Text(
              'هل أنت متأكد من إلغاء هذه الرحلة؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('تراجع'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('إلغاء الرحلة'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldCancel) return;

    setState(() => _rideState = _rideState.copyWith(isLoading: true));

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];

      if (driverId == null) {
        throw Exception('لم يتم العثور على معلومات السائق');
      }

      // تحديث حالة الرحلة في Firestore
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'driver',
      });

      // تحديث حالة السائق إلى متاح
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'status': 'available',
        'currentRideId': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء الرحلة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('خطأ في إلغاء الرحلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptRide() async {
    if (_rideState.isLoading || _rideState.isAccepted) return;

    setState(() => _rideState = _rideState.copyWith(isLoading: true));

    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      if (driverId == null) {
        throw Exception('معرّف السائق غير متوفر');
      }

      // التحقق من عدم وجود رحلة أخرى نشطة
      final currentRideId = await _checkForActiveRide(driverId);
      if (currentRideId != null &&
          currentRideId.isNotEmpty &&
          currentRideId != widget.rideId) {
        throw Exception('لا يمكن قبول هذه الرحلة لأنك مشغول في رحلة أخرى');
      }

      // استخدام Transaction للتحقق من حالة الرحلة وتحديثها
      bool rideAccepted = await FirebaseFirestore.instance
          .runTransaction<bool>((transaction) async {
        // جلب أحدث بيانات الرحلة
        final freshRideDoc = await transaction.get(
            FirebaseFirestore.instance.collection('rides').doc(widget.rideId));

        if (!freshRideDoc.exists) {
          return false; // الرحلة غير موجودة
        }

        final rideData = freshRideDoc.data()!;

        // التحقق من أن الرحلة ما زالت متاحة
        if (rideData['status'] != 'pending') {
          return false;
        }

        // تحديث حالة الرحلة والسائق
        transaction.update(
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId),
          {
            'status': 'accepted',
            'driverId': driverId,
            'acceptedAt': FieldValue.serverTimestamp(),
          },
        );

        // تحديث حالة السائق
        transaction.update(
          FirebaseFirestore.instance.collection('drivers').doc(driverId),
          {
            'status': 'busy',
            'currentRideId': widget.rideId,
          },
        );

        return true;
      });

      if (!rideAccepted) {
        throw Exception('تعذر قبول الرحلة - ربما تم قبولها من قبل سائق آخر');
      }

      // تحديث الحالة المحلية
      setState(() {
        _rideState = _rideState.copyWith(
          isAccepted: true,
        );
      });

      // جلب معلومات الزبون (مثل رقم الهاتف) بعد قبول الرحلة
      await _getCustomerInfo();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الرحلة بنجاح، يمكنك الآن بدء الرحلة'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    }
  }

  Future<String?> _checkForActiveRide(String driverId) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (driverDoc.exists) {
        return driverDoc.data()?['currentRideId'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('خطأ في التحقق من الرحلة النشطة: $e');
      return null;
    }
  }

  Future<void> _rejectRide(String reason) async {
    // تعديل الدالة لتقبل السبب وتعريضه للمستخدم
    final shouldReject = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('رفض الرحلة', textAlign: TextAlign.right),
            content: Text(
              'هل أنت متأكد من رفض هذه الرحلة؟ السبب: $reason',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('تراجع'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('رفض الرحلة'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReject) return;

    setState(() => _rideState = _rideState.copyWith(isLoading: true));

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];

      if (driverId == null) {
        throw Exception('لم يتم العثور على معلومات السائق');
      }

      // تحديث حالة الرحلة في Firestore
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': 'driver',
        'rejectionReason': reason,
      });

      // تحديث حالة السائق إلى متاح
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'status': 'available',
        'currentRideId': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم رفض الرحلة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('خطأ في رفض الرحلة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    } finally {
      setState(() => _rideState = _rideState.copyWith(isLoading: false));
    }
  }

  void _handleTimeExpiration() {
    if (_rideState.isAccepted) return; // لا نفعل شيئًا إذا تم قبول الرحلة

    // عرض رسالة للمستخدم
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('انتهى وقت قبول الرحلة'),
        backgroundColor: Colors.orange,
      ),
    );

    // العودة للشاشة الرئيسية بدلاً من رفض الرحلة تلقائيًا
    Navigator.of(context).pop();
  }
}
