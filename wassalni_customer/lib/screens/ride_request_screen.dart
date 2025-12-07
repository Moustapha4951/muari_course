import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' as intl;
import '../models/place.dart';
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';
import '../services/notification_service.dart';
import '../services/driver_location_service.dart';
import 'ride_tracking_screen.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class RideRequestScreen extends StatefulWidget {
  final Place pickupPlace;
  final Place dropoffPlace;

  const RideRequestScreen({
    super.key,
    required this.pickupPlace,
    required this.dropoffPlace,
  });

  @override
  State<RideRequestScreen> createState() => _RideRequestScreenState();
}

class _RideRequestScreenState extends State<RideRequestScreen> {
  bool _isLoading = true;
  double? _estimatedFare;
  double? _distance;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _calculateFare();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * pi / 180;
  }

  Future<void> _calculateFare() async {
    setState(() => _isLoading = true);
    
    try {
      // Calculate distance
      final distance = _calculateDistance(
        widget.pickupPlace.location.latitude,
        widget.pickupPlace.location.longitude,
        widget.dropoffPlace.location.latitude,
        widget.dropoffPlace.location.longitude,
      );

      // Get active price configuration
      final pricesQuery = await FirebaseFirestore.instance
          .collection('prices')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (pricesQuery.docs.isEmpty) {
        throw Exception('لا توجد تسعيرة نشطة');
      }

      final priceData = pricesQuery.docs.first.data();
      final minimumFare = (priceData['minimumFare'] ?? 5.0).toDouble();
      final pricePerKm = (priceData['pricePerKm'] ?? 1.0).toDouble();
      final maximumKm = (priceData['maximumKm'] ?? 0.0).toDouble();

      // Calculate fare
      double fare;
      if (distance <= maximumKm) {
        fare = minimumFare;
      } else {
        fare = minimumFare + ((distance - maximumKm) * pricePerKm);
      }

      setState(() {
        _distance = distance;
        _estimatedFare = fare;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _requestRide() async {
    setState(() => _isLoading = true);

    try {
      final userData = await SharedPreferencesHelper.getUserData();
      final customerId = userData['userId'];
      final customerName = userData['name'];
      final customerPhone = userData['phone'];

      if (customerId == null || customerName == null || customerPhone == null) {
        throw Exception('بيانات المستخدم غير متوفرة');
      }

      // Get nearby drivers within 1km range
      final cityId = widget.pickupPlace.cityId.isEmpty ? 'nouakchott' : widget.pickupPlace.cityId;
      
      debugPrint('🔵 [RideRequest] Checking for nearby drivers...');
      debugPrint('🔵 [RideRequest] Pickup location: ${widget.pickupPlace.location.latitude}, ${widget.pickupPlace.location.longitude}');
      debugPrint('🔵 [RideRequest] Pickup place cityId: $cityId');
      
      final nearbyDriverIds = await DriverLocationService.getNearbyDriverIds(
        pickupLocation: widget.pickupPlace.location,
        cityId: cityId,
        maxDistanceKm: 1.0,
      );

      if (nearbyDriverIds.isEmpty) {
        debugPrint('🔴 [RideRequest] No nearby drivers found!');
        throw Exception('لا يوجد سائقون متاحون في نطاق 1 كم من موقع الانطلاق\n\nالمدينة: $cityId\n\nتأكد من:\n- وجود سائق متصل\n- حالة السائق "متاح"\n- موافقة الإدارة على السائق');
      }

      debugPrint('🟢 [RideRequest] Found ${nearbyDriverIds.length} nearby drivers: $nearbyDriverIds');

      // Get next index for admin app
      final lastRideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .orderBy('index', descending: true)
          .limit(1)
          .get();
      
      final nextIndex = lastRideDoc.docs.isEmpty
          ? 1
          : ((lastRideDoc.docs.first.data()['index'] ?? 0) + 1);

      // Create ride document (phone hidden until driver accepts)
      final rideData = {
        'customerName': customerName,
        'customerPhone': null, // Hidden until driver accepts
        'customerId': customerId,
        'pickupLocation': widget.pickupPlace.location,
        'pickupAddress': widget.pickupPlace.name,
        'dropoffLocation': widget.dropoffPlace.location,
        'dropoffAddress': widget.dropoffPlace.name,
        'distance': _distance,
        'fare': _estimatedFare,
        'isOpen': false,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'cityId': cityId,
        'nearbyDriverIds': nearbyDriverIds, // Store nearby driver IDs for reference
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'startTime': null,
        'endTime': null,
        'index': nextIndex, // For admin app tracking
        'isFromCustomerApp': true, // Mark as customer app ride
      };

      final rideDoc = await FirebaseFirestore.instance.collection('rides').add(rideData);
      
      // Start listening to ride updates
      await NotificationService.listenToRideUpdates(rideDoc.id);

      if (mounted) {
        // Navigate to tracking screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RideTrackingScreen(rideId: rideDoc.id),
          ),
        );
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = intl.NumberFormat('#,##0.00', 'ar');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'تأكيد الرحلة',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fare Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.attach_money_rounded,
                              size: 48,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'السعر المتوقع',
                              style: AppTextStyles.arabicBody.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${formatter.format(_estimatedFare)} MRU',
                              style: AppTextStyles.arabicDisplayMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'المسافة: ${_distance!.toStringAsFixed(2)} كم',
                              style: AppTextStyles.arabicBody.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Locations Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildLocationRow(
                              icon: Icons.my_location_rounded,
                              iconColor: AppColors.success,
                              label: 'من',
                              location: widget.pickupPlace.name,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: List.generate(
                                  20,
                                  (index) => Expanded(
                                    child: Container(
                                      height: 2,
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      color: AppColors.border,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _buildLocationRow(
                              icon: Icons.location_on_rounded,
                              iconColor: AppColors.error,
                              label: 'إلى',
                              location: widget.dropoffPlace.name,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.info,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'سيتم إشعارك عند قبول السائق للرحلة',
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Confirm Button
                      ElevatedButton.icon(
                        onPressed: _requestRide,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: Text(
                          'تأكيد الطلب',
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
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String location,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
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
              const SizedBox(height: 4),
              Text(
                location,
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: AppTextStyles.arabicTitle.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'خطأ غير معروف',
              style: AppTextStyles.arabicBody.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _calculateFare();
              },
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
