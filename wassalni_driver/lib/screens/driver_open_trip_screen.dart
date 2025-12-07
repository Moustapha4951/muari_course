import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';
import 'dart:async';

class DriverOpenTripScreen extends StatefulWidget {
  final String rideId;

  const DriverOpenTripScreen({super.key, required this.rideId});

  @override
  State<DriverOpenTripScreen> createState() => _DriverOpenTripScreenState();
}

class _DriverOpenTripScreenState extends State<DriverOpenTripScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;
  
  Map<String, dynamic>? _rideData;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isProcessing = false;
  
  Position? _currentPosition;
  Position? _lastPosition;
  double _totalDistance = 0.0;
  double _totalTime = 0.0;
  double _currentFare = 0.0;
  bool _isMoving = false;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _listenToRideUpdates();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      setState(() => _currentPosition = position);
      _updateDriverLocation(position);
      
      final status = _rideData?['status'];
      final isPaused = _rideData?['isPaused'] ?? false;
      
      if (status == 'started' && !isPaused) {
        _calculateDistanceAndFare(position);
      }
    });
  }

  Future<void> _updateDriverLocation(Position position) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'driverLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  void _calculateDistanceAndFare(Position currentPos) {
    if (_lastPosition == null) {
      _lastPosition = currentPos;
      _lastUpdateTime = DateTime.now();
      return;
    }

    final now = DateTime.now();
    final timeDiff = now.difference(_lastUpdateTime ?? now).inSeconds;

    final distance = Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      currentPos.latitude,
      currentPos.longitude,
    ) / 1000;

    final speed = currentPos.speed * 3.6;
    _isMoving = speed > 1.0;

    final pricePerKm = (_rideData?['pricePerKm'] ?? 1.0).toDouble();
    final pricePerMinute = (_rideData?['pricePerMinute'] ?? 0.5).toDouble();

    if (_isMoving && distance > 0.001) {
      _totalDistance += distance;
      _currentFare += distance * pricePerKm;
      _lastPosition = currentPos;
    } else if (!_isMoving && timeDiff >= 60) {
      final minutes = timeDiff / 60.0;
      _totalTime += minutes;
      _currentFare += minutes * pricePerMinute;
      _lastUpdateTime = now;
    }

    if (timeDiff >= 5) {
      _updateTripMeters();
    }
  }

  Future<void> _updateTripMeters() async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'totalDistance': _totalDistance,
        'totalTime': _totalTime,
        'currentFare': _currentFare,
        'isMoving': _isMoving,
      });
    } catch (e) {
      debugPrint('Error updating meters: $e');
    }
  }

  void _listenToRideUpdates() {
    _rideSubscription = FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) Navigator.pop(context);
        return;
      }

      setState(() {
        _rideData = snapshot.data();
        _isLoading = false;
        _totalDistance = (_rideData?['totalDistance'] ?? 0.0).toDouble();
        _totalTime = (_rideData?['totalTime'] ?? 0.0).toDouble();
        _currentFare = (_rideData?['currentFare'] ?? 0.0).toDouble();
        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    final pickupLocation = _rideData?['pickupLocation'] as GeoPoint?;
    if (pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLocation.latitude, pickupLocation.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'نقطة الانطلاق', snippet: _rideData?['pickupAddress']),
      ));
    }
    if (_currentPosition != null) {
      _markers.add(Marker(
        markerId: const MarkerId('myLocation'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'موقعي'),
      ));
    }
  }

  Future<void> _acceptRide() async {
    setState(() => _isProcessing = true);
    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      final driverName = await SharedPreferencesHelper.getUserName();
      final driverPhone = await SharedPreferencesHelper.getUserPhone();

      // Get customer phone from actualCustomerPhone field or Firestore
      String? customerPhone = _rideData?['actualCustomerPhone'];
      
      if (customerPhone == null) {
        // Fallback: try to get from customers or clients collection
        final customerId = _rideData?['customerId'];
        if (customerId != null && customerId.toString().isNotEmpty) {
          // Try customers collection first
          var customerDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(customerId)
              .get();
          
          if (customerDoc.exists) {
            customerPhone = customerDoc.data()?['phone'];
          } else {
            // Try clients collection
            customerDoc = await FirebaseFirestore.instance
                .collection('clients')
                .doc(customerId)
                .get();
            customerPhone = customerDoc.data()?['phone'];
          }
        }
      }

      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'customerPhone': customerPhone, // Reveal phone when accepted
        'acceptedAt': FieldValue.serverTimestamp(),
        'driverLocation': _currentPosition != null ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude) : null,
      });

      await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
        'status': 'busy',
        'currentRideId': widget.rideId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الرحلة بنجاح'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updateRideStatus(String newStatus) async {
    setState(() => _isProcessing = true);
    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      final updateData = <String, dynamic>{'status': newStatus};

      if (newStatus == 'on_way') {
        updateData['onWayAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'arrived') {
        updateData['arrivedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'started') {
        updateData['startedAt'] = FieldValue.serverTimestamp();
        _lastPosition = _currentPosition;
        _lastUpdateTime = DateTime.now();
      } else if (newStatus == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
        updateData['endTime'] = FieldValue.serverTimestamp();
        updateData['fare'] = _currentFare;
        await _deductAdminFee(driverId!);
        await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({'status': 'online', 'currentRideId': null});
      }

      if (_currentPosition != null) {
        updateData['driverLocation'] = GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude);
      }

      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update(updateData);

      if (mounted) {
        String message = {'on_way': 'في الطريق إلى العميل', 'arrived': 'وصلت إلى موقع العميل', 'started': 'بدأت الرحلة', 'completed': 'تم إكمال الرحلة بنجاح'}[newStatus] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
        if (newStatus == 'completed') Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _togglePause() async {
    setState(() => _isProcessing = true);
    try {
      final isPaused = _rideData?['isPaused'] ?? false;
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'isPaused': !isPaused,
        'pausedAt': !isPaused ? FieldValue.serverTimestamp() : null,
        'resumedAt': isPaused ? FieldValue.serverTimestamp() : null,
      });

      if (isPaused) {
        _lastPosition = _currentPosition;
        _lastUpdateTime = DateTime.now();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isPaused ? 'تم استئناف الرحلة' : 'تم إيقاف الرحلة مؤقتاً'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _cancelRide() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إلغاء الرحلة', style: AppTextStyles.arabicTitle),
        content: Text('هل أنت متأكد من إلغاء هذه الرحلة؟', style: AppTextStyles.arabicBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('لا', style: AppTextStyles.arabicBody)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('نعم', style: AppTextStyles.arabicBody.copyWith(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'driver',
      });

      if (driverId != null) {
        await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({'status': 'online', 'currentRideId': null});
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deductAdminFee(String driverId) async {
    try {
      final rideFare = _currentFare;
      if (rideFare <= 0) return;

      debugPrint('💰 ========== ADMIN FEE CALCULATION (Open Trip) ==========');
      debugPrint('💰 Ride fare: $rideFare MRU');

      final pricesQuery = await FirebaseFirestore.instance.collection('prices').where('isActive', isEqualTo: true).limit(1).get();
      double commissionPercentage = 10.0;
      if (pricesQuery.docs.isNotEmpty) {
        final rawCommission = pricesQuery.docs.first.data()['appCommission'];
        debugPrint('💰 Raw appCommission from Firestore: $rawCommission (type: ${rawCommission.runtimeType})');
        commissionPercentage = (rawCommission ?? 10.0).toDouble();
      } else {
        debugPrint('💰 No active prices found, using default 10%');
      }

      final adminFee = (rideFare * commissionPercentage) / 100;
      debugPrint('💰 Commission percentage: $commissionPercentage%');
      debugPrint('💰 Calculation: ($rideFare × $commissionPercentage) / 100 = $adminFee MRU');
      debugPrint('💰 ========================================================');
      final driverDoc = await FirebaseFirestore.instance.collection('drivers').doc(driverId).get();
      if (!driverDoc.exists) return;

      final currentBalance = (driverDoc.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance - adminFee;

      await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({'balance': newBalance});
      await FirebaseFirestore.instance.collection('drivers').doc(driverId).collection('transactions').add({
        'type': 'admin_fee',
        'amount': -adminFee,
        'rideId': widget.rideId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'رسوم إدارية للرحلة المفتوحة',
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
      });

      debugPrint('✅ Admin fee deducted: $adminFee MRU');

      // Show calculation on screen
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('💰 حساب الرسوم الإدارية', style: AppTextStyles.arabicTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سعر الرحلة: ${rideFare.toStringAsFixed(2)} MRU', style: AppTextStyles.arabicBody),
                Text('نسبة العمولة: $commissionPercentage%', style: AppTextStyles.arabicBody),
                Divider(),
                Text('الحساب: (${rideFare.toStringAsFixed(2)} × $commissionPercentage) ÷ 100', style: AppTextStyles.arabicBodySmall),
                SizedBox(height: 8),
                Text('الرسوم الإدارية: ${adminFee.toStringAsFixed(2)} MRU', style: AppTextStyles.arabicTitle.copyWith(color: AppColors.error)),
                Divider(),
                Text('الرصيد السابق: ${currentBalance.toStringAsFixed(2)} MRU', style: AppTextStyles.arabicBodySmall),
                Text('الرصيد الجديد: ${newBalance.toStringAsFixed(2)} MRU', style: AppTextStyles.arabicBody.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('حسناً', style: AppTextStyles.arabicBody),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('🔴 Error deducting admin fee: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary))),
      );
    }

    final status = _rideData?['status'] ?? 'pending';
    final customerName = _rideData?['customerName'] ?? 'غير محدد';
    final customerPhone = _rideData?['customerPhone'] ?? '';
    final pickupAddress = _rideData?['pickupAddress'] ?? 'غير محدد';
    final isPaused = _rideData?['isPaused'] ?? false;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _rideData?['pickupLocation'] != null
                  ? LatLng((_rideData!['pickupLocation'] as GeoPoint).latitude, (_rideData!['pickupLocation'] as GeoPoint).longitude)
                  : const LatLng(18.0735, -15.9582),
              zoom: 14,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 16),
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))]),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      children: [
                        Text('رحلة مفتوحة', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white, fontSize: 18)),
                        Text(_getStatusText(status), style: AppTextStyles.arabicBodySmall.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (isPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(20)),
                      child: Text('متوقف', style: AppTextStyles.arabicBodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 28, backgroundColor: AppColors.primary.withOpacity(0.1), child: Icon(Icons.person, color: AppColors.primary, size: 32)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customerName, style: AppTextStyles.arabicBody.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                              if (status != 'pending')
                                Text(customerPhone.isEmpty ? 'لا يوجد رقم' : customerPhone, style: AppTextStyles.arabicBodySmall.copyWith(color: AppColors.textSecondary))
                              else
                                Text('سيظهر الرقم بعد القبول', style: AppTextStyles.arabicBodySmall.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.success.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Icon(Icons.my_location_rounded, color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(child: Text(pickupAddress, style: AppTextStyles.arabicBody)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (status == 'started') ...[
                      Row(
                        children: [
                          Expanded(child: _buildMeterCard(icon: Icons.route_rounded, label: 'المسافة', value: '${_totalDistance.toStringAsFixed(2)} كم', color: AppColors.info, isActive: _isMoving)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildMeterCard(icon: Icons.timer_rounded, label: 'الوقت', value: '${_totalTime.toStringAsFixed(0)} دقيقة', color: AppColors.warning, isActive: !_isMoving)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('التكلفة الحالية', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
                            Text('${_currentFare.toStringAsFixed(2)} MRU', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildActionButtons(status, isPaused),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeterCard({required IconData icon, required String label, required String value, required Color color, bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? color : color.withOpacity(0.3), width: isActive ? 2 : 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.arabicCaption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.arabicTitle.copyWith(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Text('نشط', style: AppTextStyles.arabicCaption.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status, bool isPaused) {
    if (status == 'pending') {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _acceptRide,
            icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Icon(Icons.check_circle_rounded),
            label: Text('قبول الرحلة', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.cancel_outlined),
            label: Text('إلغاء', style: AppTextStyles.arabicTitle.copyWith(color: AppColors.error)),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: BorderSide(color: AppColors.error, width: 2), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : () => _updateRideStatus('on_way'),
        icon: const Icon(Icons.directions_car_rounded),
        label: Text('في الطريق إلى العميل', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.info, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      );
    } else if (status == 'on_way') {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : () => _updateRideStatus('arrived'),
        icon: const Icon(Icons.location_on_rounded),
        label: Text('وصلت إلى العميل', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      );
    } else if (status == 'arrived') {
      return ElevatedButton.icon(
        onPressed: _isProcessing ? null : () => _updateRideStatus('started'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text('بدء الرحلة', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      );
    } else if (status == 'started') {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _togglePause,
                  icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(isPaused ? 'استئناف' : 'إيقاف مؤقت', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _cancelRide,
                  icon: const Icon(Icons.close_rounded),
                  label: Text('إلغاء', style: AppTextStyles.arabicBody.copyWith(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _updateRideStatus('completed'),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text('إنهاء الرحلة', style: AppTextStyles.arabicTitle.copyWith(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _getStatusText(String status) {
    return {'pending': 'في انتظار القبول', 'accepted': 'تم القبول', 'on_way': 'في الطريق', 'arrived': 'وصلت', 'started': 'جارية', 'completed': 'مكتملة', 'cancelled': 'ملغاة'}[status] ?? status;
  }
}
