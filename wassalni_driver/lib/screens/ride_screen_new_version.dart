import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/src/source.dart';
import 'package:collection/collection.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:dotted_line/dotted_line.dart';
import 'map_screen.dart';

class RideScreenNewVersion extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const RideScreenNewVersion({
    Key? key,
    required this.rideData,
    required this.rideId,
  }) : super(key: key);

  @override
  State<RideScreenNewVersion> createState() => _RideScreenNewVersionState();
}

class _RideScreenNewVersionState extends State<RideScreenNewVersion> {
  // تكوين الخريطة
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _dropoffMarkerIcon;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;

  // حالة الرحلة
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _timer;
  int _timeLeft = 15;
  bool _isAccepted = false;
  bool _isOnWay = false;
  bool _hasReachedCustomer = false;
  bool _isRideStarted = false;
  String? _currentDriverId; // إضافة متغير لتخزين معرف السائق الحالي

  // معلومات العميل
  String? _customerPhone;
  Map<String, dynamic>? _customerData;

  // للإشعارات والصوت
  final TextEditingController _cancelReasonController = TextEditingController();
  Timer? _contactReminderTimer;
  bool _hasShownContactReminder = false;
  AudioPlayer? _audioPlayer;

  // للاستماع للتغييرات
  StreamSubscription<DocumentSnapshot>? _rideSubscription;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: تم تحميل شاشة الرحلة! ${DateTime.now()}');

    // طباعة بيانات الرحلة للتشخيص
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: بيانات الرحلة: ${widget.rideData}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: معرف الرحلة: ${widget.rideId}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Ride status: ${widget.rideData['status']}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Pickup address: ${widget.rideData['pickupAddress']}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Dropoff address: ${widget.rideData['dropoffAddress']}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Fare: ${widget.rideData['fare']}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Customer ID: ${widget.rideData['customerId']}');
    debugPrint(
        '🔵 [LOGGING] RideScreenNewVersion: Assigned driver ID: ${widget.rideData['assignedDriverId']}');

    _initializeAudioPlayer();
    _prepareMapData();
    _loadDriverId(); // تحميل معرف السائق
    _monitorRideChanges();

    // التحقق من حالة الرحلة
    final status = widget.rideData['status'];
    if (status == 'accepted' ||
        status == 'on_way' ||
        status == 'started' ||
        status == 'completed') {
      setState(() {
        _isAccepted = true;
        if (status == 'on_way') _isOnWay = true;
        if (status == 'started') _isRideStarted = true;
        _timeLeft = 0;
      });
      debugPrint(
          '🟡 [LOGGING] RideScreenNewVersion: حالة الرحلة ليست pending - لن يتم بدء المؤقت');
    } else {
      debugPrint(
          '🔵 [LOGGING] RideScreenNewVersion: Starting timer for ride acceptance');
      // بدء المؤقت للقبول أو الرفض
      _startTimer();
    }
  }

  // دالة تحميل معرف السائق
  Future<void> _loadDriverId() async {
    final driverId = await SharedPreferencesHelper.getUserId();
    if (mounted) {
      setState(() {
        _currentDriverId = driverId;
      });
    }
  }

  // دالة لتجهيز بيانات الخريطة
  void _prepareMapData() {
    try {
      // إعداد أيقونات العلامات
      _setCustomMarkerIcons();

      // استخراج إحداثيات نقطة الانطلاق
      if (widget.rideData.containsKey('pickupLocation')) {
        final dynamic pickupLoc = widget.rideData['pickupLocation'];

        if (pickupLoc is GeoPoint) {
          _pickupLocation = LatLng(pickupLoc.latitude, pickupLoc.longitude);
          debugPrint('تم استخراج نقطة الانطلاق: $_pickupLocation');
        } else if (pickupLoc is Map) {
          // في حالة كانت البيانات في هيكل Map
          final double? lat = _getDoubleValue(pickupLoc, 'latitude') ??
              _getDoubleValue(pickupLoc, 'lat') ??
              _getDoubleValue(pickupLoc, '_latitude');

          final double? lng = _getDoubleValue(pickupLoc, 'longitude') ??
              _getDoubleValue(pickupLoc, 'lng') ??
              _getDoubleValue(pickupLoc, '_longitude');

          if (lat != null && lng != null) {
            _pickupLocation = LatLng(lat, lng);
            debugPrint('تم استخراج نقطة الانطلاق من Map: $_pickupLocation');
          }
        }
      }

      // استخراج إحداثيات نقطة الوصول
      if (widget.rideData.containsKey('dropoffLocation')) {
        final dynamic dropoffLoc = widget.rideData['dropoffLocation'];

        if (dropoffLoc is GeoPoint) {
          _dropoffLocation = LatLng(dropoffLoc.latitude, dropoffLoc.longitude);
          debugPrint('تم استخراج نقطة الوصول: $_dropoffLocation');
        } else if (dropoffLoc is Map) {
          // في حالة كانت البيانات في هيكل Map
          final double? lat = _getDoubleValue(dropoffLoc, 'latitude') ??
              _getDoubleValue(dropoffLoc, 'lat') ??
              _getDoubleValue(dropoffLoc, '_latitude');

          final double? lng = _getDoubleValue(dropoffLoc, 'longitude') ??
              _getDoubleValue(dropoffLoc, 'lng') ??
              _getDoubleValue(dropoffLoc, '_longitude');

          if (lat != null && lng != null) {
            _dropoffLocation = LatLng(lat, lng);
            debugPrint('تم استخراج نقطة الوصول من Map: $_dropoffLocation');
          }
        }
      }
    } catch (e) {
      debugPrint('حدث خطأ أثناء إعداد بيانات الخريطة: $e');
    }
  }

  // استخراج قيمة double من Map
  double? _getDoubleValue(Map<dynamic, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;

    final value = map[key];
    if (value is double) {
      return value;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  // إعداد أيقونات العلامات المخصصة
  Future<void> _setCustomMarkerIcons() async {
    try {
      _pickupMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/pickup_marker.png',
      ).catchError((error) {
        debugPrint('خطأ في تحميل أيقونة نقطة الانطلاق: $error');
        // استخدام اللون الأخضر للنجاح (success green)
        return BitmapDescriptor.defaultMarkerWithHue(120); // Green hue
      });

      _dropoffMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/dropoff_marker.png',
      ).catchError((error) {
        debugPrint('خطأ في تحميل أيقونة نقطة الوصول: $error');
        // استخدام اللون الأحمر للخطأ (error red)
        return BitmapDescriptor.defaultMarkerWithHue(0); // Red hue
      });
    } catch (e) {
      debugPrint('خطأ في إعداد أيقونات العلامات: $e');
      // استخدام الأيقونات الافتراضية في حالة حدوث خطأ
      _pickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(120); // Green
      _dropoffMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(0); // Red
    }
  }

  void _startTimer() {
    // التأكد من إلغاء أي مؤقت سابق
    _timer?.cancel();
    _timer = null;

    // لا نبدأ المؤقت إذا كانت الرحلة مقبولة بالفعل
    if (_isAccepted) {
      debugPrint("لن يتم بدء المؤقت لأن الرحلة مقبولة بالفعل");
      return;
    }

    _timeLeft = 15;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isAccepted) {
        // إيقاف المؤقت فورًا إذا تم قبول الرحلة
        debugPrint("تم إيقاف المؤقت بسبب قبول الرحلة");
        timer.cancel();
        return;
      }

      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          // انتهاء الوقت - إيقاف المؤقت ورفض الرحلة
          timer.cancel();
          if (mounted && !_isAccepted) {
            _rejectRide('نفذ الوقت');
          }
        }
      });
    });
  }

  // دالة لمراقبة تغييرات الرحلة
  void _monitorRideChanges() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final status = data['status'];
      final assignedDriverId = data['driverId'];

      // إذا كانت الرحلة مقبولة، تحقق من أن السائق الحالي هو من قبل الرحلة
      if (status == 'accepted' && _currentDriverId != null) {
        if (assignedDriverId == _currentDriverId) {
          // هذا السائق قبل الرحلة - تحديث الحالة المحلية فقط
          if (!_isAccepted) {
            setState(() {
              _isAccepted = true;
              _timeLeft = 0;
            });
          }
        }
      }

      // التحقق من إلغاء الرحلة من قبل الإدارة فقط
      if (status == 'cancelled' && data['cancelledBy'] == 'admin') {
        final cancelReason = data['cancelReason'] ?? 'لا يوجد سبب محدد';
        _showAdminCancellationDialog(cancelReason);
      }
    });
  }

  // دالة عرض رسالة إلغاء الرحلة من الإدارة
  void _showAdminCancellationDialog(String reason) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('تم إلغاء الرحلة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تم إلغاء هذه الرحلة من قبل الإدارة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('السبب: $reason'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  // دالة للاتصال بالعميل
  void _callCustomer() async {
    if (_customerPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم الهاتف غير متوفر')),
      );
      return;
    }

    final url = 'tel:${_customerPhone!}';
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        throw 'لا يمكن الاتصال بالرقم $_customerPhone';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  // دالة لرفض الرحلة
  Future<void> _rejectRide(String reason) async {
    // تأكيد مزدوج على عدم قبول الرحلة
    if (_isAccepted || _isRideStarted) {
      debugPrint('محاولة رفض رحلة مقبولة/بدأت بالفعل - تم تجاهل الطلب');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final driverId = await SharedPreferencesHelper.getUserId();

      if (driverId == null) {
        throw Exception('معرّف السائق غير متوفر');
      }

      // تحديث الرحلة لتسجيل الرفض
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'rejectedBy': FieldValue.arrayUnion([driverId]),
        'rejectionReason': reason,
      });

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('خطأ في رفض الرحلة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeAudioPlayer() async {
    _audioPlayer = AudioPlayer();
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer?.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('خطأ في تشغيل صوت الإشعار: $e');
    }
  }

  void _startCatalogTimer() {
    _catalogTimer?.cancel();
    _catalogTimer = Timer(const Duration(minutes: 1), () {
      if (mounted && _isAccepted) {
        setState(() {
          _showCatalog = true;
        });
        _playNotificationSound();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _contactReminderTimer?.cancel();
    _catalogTimer?.cancel();
    _rideSubscription?.cancel();
    _audioPlayer?.dispose();
    _cancelReasonController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Timer? _catalogTimer;
  bool _showCatalog = false;

  void _makePhoneCall() async {
    if (_customerPhone != null) {
      final url = 'tel:$_customerPhone';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      }
    }
  }

  Widget _buildCatalogDialog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "رحلة جديدة",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'تم قبول الرحلة! هل تريد الاتصال بالزبون؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCatalog = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                ),
                child: const Text('لاحقاً'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCatalog = false;
                  });
                  _makePhoneCall();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('اتصال الآن'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorCard(String message, {VoidCallback? onRetry}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _updateMapMarkers() {
    setState(() {
      _markers.clear();
      if (_pickupLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: _pickupMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'نقطة الانطلاق'),
        ));
      }
      if (_dropoffLocation != null) {
        _markers.add(Marker(
          markerId: const MarkerId('dropoff'),
          position: _dropoffLocation!,
          icon: _dropoffMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'نقطة الوصول'),
        ));
      }
    });
  }

  void _drawRouteLine() {
    if (_pickupLocation == null || _dropoffLocation == null) return;
    
    setState(() {
      _polylines.clear();
      _polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [_pickupLocation!, _dropoffLocation!],
        color: AppColors.primary,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    });
  }

  void _adjustMapCamera() {
    if (_mapController == null) return;
    
    if (_pickupLocation != null && _dropoffLocation != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLocation!.latitude < _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude < _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
        northeast: LatLng(
          _pickupLocation!.latitude > _dropoffLocation!.latitude
              ? _pickupLocation!.latitude
              : _dropoffLocation!.latitude,
          _pickupLocation!.longitude > _dropoffLocation!.longitude
              ? _pickupLocation!.longitude
              : _dropoffLocation!.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } else if (_pickupLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation!, 15));
    }
  }

  void _showExitConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الخروج'),
        content: const Text('هل أنت متأكد أنك تريد الخروج من هذه الشاشة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل أنت متأكد أنك تريد إلغاء هذه الرحلة؟'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء',
                hintText: 'الرجاء توضيح سبب الإلغاء',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                Navigator.pop(context);
                _rejectRide(reasonController.text);
              }
            },
            child: const Text('تأكيد الإلغاء', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          _buildMapLayer(),

          // 2. Top Bar Layer
          _buildTopBarLayer(),

          // 3. Price Badge
          _buildPriceBadge(),

          // 4. Bottom Sheet Layer
          _buildBottomSheet(),

          // 5. Loading & Error Overlays
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: _buildLoadingIndicator(),
            ),
            
          if (_errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              right: 20,
              child: _buildErrorCard(
                _errorMessage!,
                onRetry: () => setState(() => _errorMessage = null),
              ),
            ),
            
          // 6. Catalog Dialog (if needed)
          if (_showCatalog)
            Container(
              color: Colors.black54,
              child: Center(child: _buildCatalogDialog()),
            ),
        ],
      ),
    );
  }

  Widget _buildMapLayer() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _pickupLocation ?? const LatLng(18.0735, -15.9582),
        zoom: 15,
      ),
      markers: _markers,
      polylines: _polylines,
      zoomControlsEnabled: false,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        _updateMapMarkers();
        _drawRouteLine();
        _adjustMapCamera();
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
                onPressed: () {
                  if (!_isAccepted) {
                    _showExitConfirmationDialog();
                  } else {
                    _showCancelConfirmationDialog();
                  }
                },
              ),
            ),
            const Spacer(),
            // Title
            Text(
              'رحلة جديدة',
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
            // Call Button
            if (_customerPhone != null && _isAccepted)
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

  Widget _buildPriceBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_money_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${widget.rideData['fare'] ?? '0'} MRU',
                style: AppTextStyles.arabicTitle.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Timer / Status
                if (_timeLeft > 0 && !_isAccepted)
                  _buildTimerWidget()
                else if (_isAccepted)
                  _buildStatusWidget(),

                const SizedBox(height: 20),

                // 2. Customer Info (if accepted)
                if (_isAccepted) _buildCustomerInfo(),

                // 3. Route Info
                _buildRouteInfo(),

                const SizedBox(height: 20),

                // 4. Action Buttons
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _timeLeft < 5
            ? AppColors.error.withOpacity(0.1)
            : AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _timeLeft < 5 ? AppColors.error : AppColors.warning,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_rounded,
              color: _timeLeft < 5 ? AppColors.error : AppColors.warning),
          const SizedBox(width: 8),
          Text(
            'قبول خلال: $_timeLeft ثانية',
            style: AppTextStyles.arabicBody.copyWith(
              color: _timeLeft < 5 ? AppColors.error : AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget() {
    String statusText = 'تم قبول الرحلة';
    Color statusColor = AppColors.success;
    IconData statusIcon = Icons.check_circle_rounded;

    if (_isOnWay) {
      statusText = 'في الطريق للزبون';
      statusColor = AppColors.info;
      statusIcon = Icons.directions_car_rounded;
    }
    if (_isRideStarted) {
      statusText = 'الرحلة جارية';
      statusColor = AppColors.primary;
      statusIcon = Icons.play_circle_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: AppTextStyles.arabicBody.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    final customerPhone = widget.rideData['customerPhone'] ?? _customerPhone;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'معلومات الزبون',
                  style: AppTextStyles.arabicBodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  customerPhone ?? 'رقم غير متوفر',
                  style: AppTextStyles.arabicBody.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _callCustomer,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_rounded,
                  color: AppColors.success, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Column(
      children: [
        // Pickup
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.my_location_rounded,
                  color: AppColors.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نقطة الانطلاق',
                      style: AppTextStyles.arabicBodySmall
                          .copyWith(color: AppColors.textSecondary)),
                  Text(
                    widget.rideData['pickupAddress'] ?? 'غير محدد',
                    style: AppTextStyles.arabicBody
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Dotted Line
        if (widget.rideData['dropoffAddress'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 20,
                child: DottedLine(
                  direction: Axis.vertical,
                  lineLength: 20,
                  lineThickness: 2,
                  dashLength: 4,
                  dashColor: AppColors.divider,
                ),
              ),
            ),
          ),

        // Dropoff
        if (widget.rideData['dropoffAddress'] != null)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: AppColors.error, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('نقطة الوصول',
                        style: AppTextStyles.arabicBodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    Text(
                      widget.rideData['dropoffAddress'],
                      style: AppTextStyles.arabicBody
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (!_isAccepted) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _rejectRide('رفض السائق'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('رفض',
                  style: AppTextStyles.arabicTitle
                      .copyWith(color: AppColors.error, fontSize: 16)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _acceptRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text('قبول',
                  style: AppTextStyles.arabicTitle
                      .copyWith(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      );
    }

    if (!_isOnWay) {
      return _buildFullWidthButton(
        onPressed: _isLoading ? null : _moveToOnWay,
        label: 'في الطريق للزبون',
        icon: Icons.directions_car_rounded,
        color: AppColors.info,
      );
    }

    if (!_isRideStarted) {
      return _buildFullWidthButton(
        onPressed: _isLoading ? null : _beginRide,
        label: 'بدء الرحلة',
        icon: Icons.play_arrow_rounded,
        color: AppColors.primary,
      );
    }

    return _buildFullWidthButton(
      onPressed: _isLoading ? null : _completeRide,
      label: 'إكمال الرحلة',
      icon: Icons.flag_rounded,
      color: AppColors.success,
    );
  }

  Widget _buildFullWidthButton({
    required VoidCallback? onPressed,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: color.withOpacity(0.4),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: AppTextStyles.arabicTitle
            .copyWith(color: Colors.white, fontSize: 18),
      ),
    );
  }

  // دالة وهمية لقبول الرحلة - يمكن استكمالها بمنطق الأعمال الفعلي
  Future<void> _acceptRide() async {
    if (_isLoading || _isAccepted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentDriverId == null) {
        _currentDriverId = await SharedPreferencesHelper.getUserId();
      }

      if (_currentDriverId == null) {
        throw Exception('معرّف السائق غير متوفر');
      }

      // فحص حالة الرحلة قبل القبول
      final rideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .get();

      if (!rideDoc.exists) {
        throw Exception('الرحلة غير موجودة');
      }

      final rideData = rideDoc.data()!;
      if (rideData['status'] != 'pending') {
        throw Exception('هذه الرحلة لم تعد متاحة');
      }

      // تحديث حالة الرحلة في Firestore
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'accepted',
        'driverId': _currentDriverId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isAccepted = true;
          _timeLeft = 0;
          _customerPhone = widget.rideData['customerPhone'];
        });

        // إعادة رسم المسار وضبط الكاميرا
        _drawRouteLine();
        _adjustMapCamera();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في قبول الرحلة: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في قبول الرحلة. يرجى المحاولة مرة أخرى.';
        });
        _showErrorSnackbar('حدث خطأ في قبول الرحلة');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // دالة وهمية للانتقال إلى حالة "في الطريق"
  Future<void> _moveToOnWay() async {
    if (!_isAccepted || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // تحديث حالة الرحلة في Firestore
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'on_way',
        'onWayAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isOnWay = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الحالة إلى "في الطريق"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في تحديث حالة الرحلة: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'حدث خطأ في تحديث حالة الرحلة. يرجى المحاولة مرة أخرى.';
        });
        _showErrorSnackbar('حدث خطأ في تحديث حالة الرحلة');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // دالة وهمية لبدء الرحلة
  Future<void> _beginRide() async {
    if (!_isOnWay || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // تحديث حالة الرحلة في Firestore
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'started',
        'startedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isRideStarted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم بدء الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('خطأ في بدء الرحلة: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في بدء الرحلة. يرجى المحاولة مرة أخرى.';
        });
        _showErrorSnackbar('حدث خطأ في بدء الرحلة');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // دالة وهمية لإلغاء الرحلة
  Future<void> _cancelRide() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الإلغاء', textAlign: TextAlign.right),
        content: TextField(
          controller: _cancelReasonController,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الإلغاء هنا',
          ),
          textAlign: TextAlign.right,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_cancelReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الإلغاء')),
                );
                return;
              }
              Navigator.of(context).pop();
              // هنا يمكن إضافة منطق إلغاء الرحلة على الخادم
              Navigator.of(context).pop(); // العودة للشاشة السابقة
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  // دالة وهمية لإكمال الرحلة
  Future<void> _completeRide() async {
    if (!_isRideStarted || _isLoading) {
      _showErrorSnackbar('لا يمكن إكمال الرحلة قبل بدئها');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // التحقق من معرف السائق
      if (_currentDriverId == null) {
        throw Exception('معرف السائق غير متوفر');
      }

      // التحقق من وجود الرحلة
      final rideRef =
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
      final driverRef = FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId);

      final rideDoc = await rideRef.get();
      if (!rideDoc.exists) {
        throw Exception('الرحلة غير موجودة');
      }

      final rideData = rideDoc.data()!;
      final rideFare = rideData['fare'] as num? ?? 0;

      if (rideFare <= 0) {
        throw Exception('سعر الرحلة غير صحيح: $rideFare');
      }

      // جلب نسبة الإدارة من إعدادات التطبيق
      final pricesDoc = await FirebaseFirestore.instance
          .collection('prices')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      double appCommission = 0.2; // نسبة افتراضية 20%
      if (pricesDoc.docs.isNotEmpty) {
        appCommission = (pricesDoc.docs.first.data()['appCommission'] as num?)
                ?.toDouble() ??
            0.2;
      }

      final adminFee = (rideFare * appCommission).round();
      debugPrint(
          'حساب الرسوم: السعر = $rideFare, النسبة = ${appCommission * 100}%, المبلغ = $adminFee');

      // تحديث البيانات في Firestore
      final batch = FirebaseFirestore.instance.batch();

      batch.update(rideRef, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'adminFee': adminFee,
        'actualFare': rideFare,
        'driverEarnings': rideFare - adminFee,
      });

      // تحديث رصيد السائق
      batch.update(driverRef, {
        'balance': FieldValue.increment(-adminFee),
        'totalTrips': FieldValue.increment(1),
        'totalEarnings': FieldValue.increment(rideFare - adminFee),
      });

      // تنفيذ التحديثات
      await batch.commit();

      if (mounted) {
        // عرض رسالة نجاح تفصيلية
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تم إكمال الرحلة بنجاح'),
                Text('سعر الرحلة: $rideFare MRU'),
                Text('رسوم الإدارة: $adminFee MRU'),
                Text('صافي الربح: ${rideFare - adminFee} MRU'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );

        // العودة إلى الشاشة الرئيسية
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('خطأ مفصل في إكمال الرحلة: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ في إكمال الرحلة. يرجى المحاولة مرة أخرى.';
        });
        _showErrorSnackbar('حدث خطأ في إكمال الرحلة: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
