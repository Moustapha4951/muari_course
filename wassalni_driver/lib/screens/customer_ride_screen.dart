import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';
import 'home_screen.dart';
import 'dart:async';

class CustomerRideScreen extends StatefulWidget {
  final String rideId;

  const CustomerRideScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<CustomerRideScreen> createState() => _CustomerRideScreenState();
}

class _CustomerRideScreenState extends State<CustomerRideScreen> {
  GoogleMapController? _mapController;
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Map<String, dynamic>? _rideData;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isAccepting = false;
  Position? _currentPosition;
  Timer? _acceptanceTimer;
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _listenToRideUpdates();
    _getCurrentLocation();
    _startAcceptanceTimer();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _acceptanceTimer?.cancel();
    super.dispose();
  }

  void _startAcceptanceTimer() {
    _acceptanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        // Auto-reject if not accepted
        if (_rideData?['status'] == 'pending' && mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  void _getCurrentLocation() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  void _listenToRideUpdates() {
    _rideSubscription = FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) Navigator.pop(context);
        return;
      }

      setState(() {
        _rideData = snapshot.data();
        _isLoading = false;
        _updateMarkers();
      });

      // Check if ride was accepted by another driver
      final status = _rideData?['status'];
      final driverId = _rideData?['driverId'];
      
      if (status == 'accepted' && driverId != null) {
        _checkIfAcceptedByMe(driverId);
      }
    });
  }

  Future<void> _checkIfAcceptedByMe(String acceptedDriverId) async {
    final myDriverId = await SharedPreferencesHelper.getUserId();
    if (myDriverId != acceptedDriverId && mounted) {
      // Another driver accepted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الرحلة من سائق آخر'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _updateMarkers() {
    _markers.clear();

    // Pickup marker
    final pickupLocation = _rideData?['pickupLocation'] as GeoPoint?;
    if (pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickupLocation.latitude, pickupLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'نقطة الانطلاق',
            snippet: _rideData?['pickupAddress'],
          ),
        ),
      );
    }

    // Dropoff marker
    final dropoffLocation = _rideData?['dropoffLocation'] as GeoPoint?;
    if (dropoffLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoffLocation.latitude, dropoffLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'نقطة الوصول',
            snippet: _rideData?['dropoffAddress'],
          ),
        ),
      );
    }

    // My location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('myLocation'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'موقعي'),
        ),
      );
    }
  }

  Future<void> _acceptRide() async {
    setState(() => _isAccepting = true);

    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      final driverName = await SharedPreferencesHelper.getUserName();
      final driverPhone = await SharedPreferencesHelper.getUserPhone();

      if (driverId == null || driverName == null || driverPhone == null) {
        throw Exception('بيانات السائق غير متوفرة');
      }

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

      // Update ride with driver info and reveal customer phone
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'customerPhone': customerPhone, // Reveal phone when accepted
        'acceptedAt': FieldValue.serverTimestamp(),
        'driverLocation': _currentPosition != null
            ? GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude)
            : null,
      });

      // Update driver status to busy
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'status': 'busy',
        'currentRideId': widget.rideId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الرحلة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في قبول الرحلة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  Future<void> _updateRideStatus(String newStatus) async {
    setState(() => _isAccepting = true);

    try {
      final driverId = await SharedPreferencesHelper.getUserId();
      if (driverId == null) throw Exception('معرف السائق غير متوفر');

      final updateData = <String, dynamic>{
        'status': newStatus,
      };

      // Add timestamps for specific statuses
      if (newStatus == 'on_way') {
        updateData['onWayAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'arrived') {
        updateData['arrivedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'started') {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
        updateData['endTime'] = FieldValue.serverTimestamp();
        
        // Deduct admin fee from driver's balance
        await _deductAdminFee(driverId);
        
        // Update driver status back to online
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .update({'status': 'online', 'currentRideId': null});
      }

      // Update current location
      if (_currentPosition != null) {
        updateData['driverLocation'] = GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update(updateData);

      if (mounted) {
        String message = '';
        switch (newStatus) {
          case 'on_way':
            message = 'في الطريق إلى العميل';
            break;
          case 'arrived':
            message = 'وصلت إلى موقع العميل';
            break;
          case 'started':
            message = 'بدأت الرحلة';
            break;
          case 'completed':
            message = 'تم إكمال الرحلة بنجاح';
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home screen if completed
        if (newStatus == 'completed') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  Future<void> _deductAdminFee(String driverId) async {
    try {
      // Get ride fare
      final rideFare = (_rideData?['fare'] ?? 0.0).toDouble();
      if (rideFare <= 0) {
        debugPrint('🔴 Cannot deduct admin fee: Invalid ride fare');
        return;
      }

      // Get admin commission percentage from active price configuration
      final pricesQuery = await FirebaseFirestore.instance
          .collection('prices')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      debugPrint('💰 ========== ADMIN FEE CALCULATION ==========');
      debugPrint('💰 Ride fare: $rideFare MRU');

      double commissionPercentage = 10.0; // Default 10%
      if (pricesQuery.docs.isNotEmpty) {
        final priceData = pricesQuery.docs.first.data();
        final rawCommission = priceData['appCommission'];
        debugPrint('💰 Raw appCommission from Firestore: $rawCommission (type: ${rawCommission.runtimeType})');
        commissionPercentage = (rawCommission ?? 10.0).toDouble();
      } else {
        debugPrint('💰 No active prices found, using default 10%');
      }

      // Calculate admin fee as percentage of ride fare
      final adminFee = (rideFare * commissionPercentage) / 100;
      debugPrint('💰 Commission percentage: $commissionPercentage%');
      debugPrint('💰 Calculation: ($rideFare × $commissionPercentage) / 100 = $adminFee MRU');
      debugPrint('💰 ==========================================');

      // Get driver's current balance
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) return;

      final currentBalance = (driverDoc.data()?['balance'] ?? 0.0).toDouble();
      final newBalance = currentBalance - adminFee;

      // Update driver's balance
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'balance': newBalance,
      });

      // Record transaction
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .collection('transactions')
          .add({
        'type': 'admin_fee',
        'amount': -adminFee,
        'rideId': widget.rideId,
        'timestamp': FieldValue.serverTimestamp(),
        'description': 'رسوم إدارية للرحلة',
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
      });

      debugPrint('✅ Admin fee deducted successfully');

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
                Text('سعر الرحلة: $rideFare MRU', style: AppTextStyles.arabicBody),
                Text('نسبة العمولة: $commissionPercentage%', style: AppTextStyles.arabicBody),
                Divider(),
                Text('الحساب: ($rideFare × $commissionPercentage) ÷ 100', style: AppTextStyles.arabicBodySmall),
                SizedBox(height: 8),
                Text('الرسوم الإدارية: $adminFee MRU', style: AppTextStyles.arabicTitle.copyWith(color: AppColors.error)),
                Divider(),
                Text('الرصيد السابق: $currentBalance MRU', style: AppTextStyles.arabicBodySmall),
                Text('الرصيد الجديد: $newBalance MRU', style: AppTextStyles.arabicBody.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
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
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final pickupAddress = _rideData?['pickupAddress'] ?? 'غير محدد';
    final dropoffAddress = _rideData?['dropoffAddress'] ?? 'غير محدد';
    final customerName = _rideData?['customerName'] ?? 'غير محدد';
    final customerPhone = _rideData?['customerPhone'] ?? '';
    final fare = _rideData?['fare']?.toDouble() ?? 0.0;
    final distance = _rideData?['distance']?.toDouble() ?? 0.0;

    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _rideData?['pickupLocation'] != null
                  ? LatLng(
                      (_rideData!['pickupLocation'] as GeoPoint).latitude,
                      (_rideData!['pickupLocation'] as GeoPoint).longitude,
                    )
                  : const LatLng(18.0735, -15.9582),
              zoom: 14,
            ),
            markers: _markers,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Top Bar with Timer
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'طلب رحلة جديد',
                          style: AppTextStyles.arabicTitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _remainingSeconds > 10
                                ? Colors.white.withOpacity(0.2)
                                : Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_remainingSeconds ثانية',
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Info Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Customer Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customerName,
                                  style: AppTextStyles.arabicBody.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  customerPhone,
                                  style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ride Details
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.attach_money_rounded,
                            label: 'السعر',
                            value: '${fare.toStringAsFixed(2)} MRU',
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoCard(
                            icon: Icons.route_rounded,
                            label: 'المسافة',
                            value: '${distance.toStringAsFixed(2)} كم',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Locations
                    _buildLocationRow(
                      icon: Icons.my_location_rounded,
                      iconColor: AppColors.success,
                      label: 'من',
                      value: pickupAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildLocationRow(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      label: 'إلى',
                      value: dropoffAddress,
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons based on status
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.arabicBody.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.arabicCaption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final status = _rideData?['status'] ?? 'pending';

    if (status == 'pending') {
      // Show accept and cancel buttons
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: _isAccepting ? null : _acceptRide,
            icon: _isAccepting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _isAccepting ? 'جاري القبول...' : 'قبول الرحلة',
              style: AppTextStyles.arabicTitle.copyWith(
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isAccepting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.cancel_outlined),
            label: Text(
              'إلغاء',
              style: AppTextStyles.arabicTitle.copyWith(
                color: AppColors.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'accepted') {
      // Show "On My Way" button
      return ElevatedButton.icon(
        onPressed: _isAccepting ? null : () => _updateRideStatus('on_way'),
        icon: _isAccepting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.directions_car_rounded),
        label: Text(
          'في الطريق إلى العميل',
          style: AppTextStyles.arabicTitle.copyWith(
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.info,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    } else if (status == 'on_way') {
      // Show "Arrived" button
      return ElevatedButton.icon(
        onPressed: _isAccepting ? null : () => _updateRideStatus('arrived'),
        icon: _isAccepting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.location_on_rounded),
        label: Text(
          'وصلت إلى العميل',
          style: AppTextStyles.arabicTitle.copyWith(
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warning,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    } else if (status == 'arrived') {
      // Show "Start Trip" button
      return ElevatedButton.icon(
        onPressed: _isAccepting ? null : () => _updateRideStatus('started'),
        icon: _isAccepting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(
          'بدء الرحلة',
          style: AppTextStyles.arabicTitle.copyWith(
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    } else if (status == 'started') {
      // Show "Complete Trip" button
      return ElevatedButton.icon(
        onPressed: _isAccepting ? null : () => _updateRideStatus('completed'),
        icon: _isAccepting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle_outline_rounded),
        label: Text(
          'إنهاء الرحلة',
          style: AppTextStyles.arabicTitle.copyWith(
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    } else {
      // Completed or other status
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            Text(
              'تم إكمال الرحلة',
              style: AppTextStyles.arabicTitle.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }
  }
}
