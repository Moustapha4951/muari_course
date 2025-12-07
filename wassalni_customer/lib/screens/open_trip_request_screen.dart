import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place.dart';
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';
import '../services/driver_location_service.dart';
import 'open_trip_tracking_screen.dart';

class OpenTripRequestScreen extends StatefulWidget {
  final Place pickupPlace;

  const OpenTripRequestScreen({
    super.key,
    required this.pickupPlace,
  });

  @override
  State<OpenTripRequestScreen> createState() => _OpenTripRequestScreenState();
}

class _OpenTripRequestScreenState extends State<OpenTripRequestScreen> {
  bool _isLoading = false;
  double? _pricePerKm;
  double? _pricePerMinute;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final pricesQuery = await FirebaseFirestore.instance
          .collection('prices')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (pricesQuery.docs.isNotEmpty) {
        final priceData = pricesQuery.docs.first.data();
        setState(() {
          _pricePerKm = (priceData['pricePerKm'] ?? 1.0).toDouble();
          _pricePerMinute = (priceData['pricePerMinute'] ?? 0.5).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Error loading pricing: $e');
    }
  }

  Future<void> _requestOpenTrip() async {
    setState(() => _isLoading = true);

    try {
      final userData = await SharedPreferencesHelper.getUserData();
      final customerId = userData['userId'];
      final customerName = userData['name'];
      final customerPhone = userData['phone'];

      if (customerId == null || customerName == null || customerPhone == null) {
        throw Exception('بيانات المستخدم غير متوفرة');
      }

      // Get nearby drivers
      final cityId = widget.pickupPlace.cityId.isEmpty ? 'nouakchott' : widget.pickupPlace.cityId;
      
      debugPrint('🔵 [OpenTripRequest] Checking for nearby drivers...');
      debugPrint('🔵 [OpenTripRequest] Pickup location: ${widget.pickupPlace.location.latitude}, ${widget.pickupPlace.location.longitude}');
      debugPrint('🔵 [OpenTripRequest] Pickup place cityId: $cityId');
      
      final nearbyDriverIds = await DriverLocationService.getNearbyDriverIds(
        pickupLocation: widget.pickupPlace.location,
        cityId: cityId,
        maxDistanceKm: 1.0,
      );

      if (nearbyDriverIds.isEmpty) {
        debugPrint('🔴 [OpenTripRequest] No nearby drivers found!');
        throw Exception('لا يوجد سائقون متاحون في نطاق 1 كم من موقع الانطلاق\n\nالمدينة: $cityId\n\nتأكد من:\n- وجود سائق متصل\n- حالة السائق "متاح"\n- موافقة الإدارة على السائق');
      }
      
      debugPrint('🟢 [OpenTripRequest] Found ${nearbyDriverIds.length} nearby drivers: $nearbyDriverIds');

      // Get next index for admin app
      final lastRideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .orderBy('index', descending: true)
          .limit(1)
          .get();
      
      final nextIndex = lastRideDoc.docs.isEmpty
          ? 1
          : ((lastRideDoc.docs.first.data()['index'] ?? 0) + 1);

      // Create open trip document (phone hidden until driver accepts)
      final tripData = {
        'customerName': customerName,
        'customerPhone': null, // Hidden until driver accepts
        'customerId': customerId,
        'pickupLocation': widget.pickupPlace.location,
        'pickupAddress': widget.pickupPlace.name,
        'dropoffLocation': null,
        'dropoffAddress': null,
        'isOpen': true,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'cityId': cityId,
        'nearbyDriverIds': nearbyDriverIds,
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'startTime': null,
        'endTime': null,
        // Open trip specific fields
        'totalDistance': 0.0,
        'totalTime': 0.0, // in minutes
        'movingDistance': 0.0,
        'stoppedTime': 0.0, // in minutes
        'currentFare': 0.0,
        'pricePerKm': _pricePerKm ?? 1.0,
        'pricePerMinute': _pricePerMinute ?? 0.5,
        'isPaused': false,
        'pausedAt': null,
        'resumedAt': null,
        'index': nextIndex, // For admin app tracking
        'isFromCustomerApp': true, // Mark as customer app ride
      };

      final tripDoc = await FirebaseFirestore.instance
          .collection('rides')
          .add(tripData);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OpenTripTrackingScreen(rideId: tripDoc.id),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'طلب رحلة مفتوحة',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Card
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
                    Icons.explore_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'رحلة مفتوحة',
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'بدون وجهة محددة',
                    style: AppTextStyles.arabicBody.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pricing Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'التسعيرة',
                    style: AppTextStyles.arabicTitle.copyWith(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPriceRow(
                    icon: Icons.route_rounded,
                    label: 'سعر الكيلومتر',
                    value: '${_pricePerKm?.toStringAsFixed(2) ?? "..."} MRU',
                    color: AppColors.info,
                  ),
                  const SizedBox(height: 12),
                  _buildPriceRow(
                    icon: Icons.timer_rounded,
                    label: 'سعر الدقيقة (عند التوقف)',
                    value: '${_pricePerMinute?.toStringAsFixed(2) ?? "..."} MRU',
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pickup Location
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.my_location_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نقطة الانطلاق',
                          style: AppTextStyles.arabicCaption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.pickupPlace.name,
                          style: AppTextStyles.arabicBody.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Info Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'سيتم حساب التكلفة بناءً على المسافة المقطوعة والوقت المستغرق',
                      style: AppTextStyles.arabicBodySmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Request Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _requestOpenTrip,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isLoading ? 'جاري الإرسال...' : 'طلب رحلة مفتوحة',
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

  Widget _buildPriceRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.arabicBody,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.arabicBody.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
