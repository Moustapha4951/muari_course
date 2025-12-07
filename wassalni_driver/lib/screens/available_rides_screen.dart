import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import 'ride_screen_new_version.dart';

class AvailableRidesScreen extends StatefulWidget {
  const AvailableRidesScreen({super.key});

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  final List<Map<String, dynamic>> _availableRides = [];
  Position? _currentPosition;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _loadAvailableRides();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint(
          'الموقع الحالي: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');

      await _loadAvailableRides();
    } catch (e) {
      debugPrint('خطأ في تهيئة البيانات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableRides() async {
    try {
      debugPrint('بدء تحميل الرحلات المتوفرة...');

      final QuerySnapshot rides = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'pending')
          .get();

      debugPrint('تم العثور على ${rides.docs.length} رحلة');
      _availableRides.clear();

      for (var doc in rides.docs) {
        final rideData = doc.data() as Map<String, dynamic>;
        final createdAt = rideData['createdAt'] as Timestamp?;

        if (createdAt != null) {
          final age = DateTime.now().difference(createdAt.toDate());

          if (age.inSeconds > 15) {
            await FirebaseFirestore.instance
                .collection('rides')
                .doc(doc.id)
                .update({'status': 'timeout'});
            debugPrint('تم تحديث حالة الرحلة ${doc.id} إلى timeout');
            continue;
          }

          final pickupLocation = rideData['pickupLocation'] as GeoPoint?;
          if (pickupLocation == null) continue;

          if (_currentPosition != null) {
            final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              pickupLocation.latitude,
              pickupLocation.longitude,
            );

            if (distance <= 5000) {
              final timeLeft = 15 - age.inSeconds;
              _availableRides.add({
                ...rideData,
                'id': doc.id,
                'distance': (distance / 1000).toStringAsFixed(1),
                'timeLeft': timeLeft,
              });
              debugPrint(
                  'تمت إضافة الرحلة ${doc.id} للقائمة المتوفرة. المسافة: ${(distance / 1000).toStringAsFixed(1)} كم، الوقت المتبقي: $timeLeft ثانية');
            } else {
              debugPrint(
                  'تم تجاهل الرحلة ${doc.id} لأنها بعيدة جداً (${(distance / 1000).toStringAsFixed(1)} كم)');
            }
          }
        }
      }

      _availableRides.sort((a, b) {
        final distanceA = double.parse(a['distance'].toString());
        final distanceB = double.parse(b['distance'].toString());
        if ((distanceB - distanceA).abs() > 0.5) {
          return distanceA.compareTo(distanceB);
        }
        final timeLeftA = a['timeLeft'] as int;
        final timeLeftB = b['timeLeft'] as int;
        return timeLeftB
            .compareTo(timeLeftA);
      });

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('خطأ في تحميل الرحلات: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الرحلات: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.25),
                                Colors.white.withOpacity(0.15),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            onPressed: _loadAvailableRides,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المشاوير المتوفرة',
                      style: AppTextStyles.arabicDisplaySmall.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Area
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : _availableRides.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      size: 64,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'لا توجد مشاوير متوفرة',
                                    style: AppTextStyles.arabicTitle.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'قريبة منك حالياً',
                                    style: AppTextStyles.arabicBody.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadAvailableRides,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: _availableRides.length,
                                itemBuilder: (context, index) {
                                  final ride = _availableRides[index];
                                  final timeLeft = ride['timeLeft'] as int;
                                  final fare = ride['fare']?.toString() ?? '0';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          debugPrint('الانتقال إلى تفاصيل الرحلة: ${ride['id']}');
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => RideScreenNewVersion(
                                                rideData: Map<String, dynamic>.from(ride),
                                                rideId: ride['id'],
                                              ),
                                            ),
                                          ).then((value) => _loadAvailableRides());
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Pickup Location
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      gradient: AppColors.primaryGradient,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Icon(
                                                      Icons.location_on_rounded,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      ride['pickupAddress'],
                                                      style: AppTextStyles.arabicBody.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              // Dropoff Location
                                              if (ride['dropoffAddress'] != null) ...[
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.error.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Icon(
                                                        Icons.flag_rounded,
                                                        color: AppColors.error,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        ride['dropoffAddress'],
                                                        style: AppTextStyles.arabicBody.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              
                                              const SizedBox(height: 16),
                                              
                                              // Info Row
                                              Row(
                                                children: [
                                                  // Distance
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.info.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.near_me_rounded,
                                                            size: 16,
                                                            color: AppColors.info,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '${ride['distance']} كم',
                                                            style: AppTextStyles.arabicBodySmall.copyWith(
                                                              color: AppColors.info,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  
                                                  // Timer
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        gradient: timeLeft < 5
                                                            ? LinearGradient(
                                                                colors: [
                                                                  AppColors.error,
                                                                  AppColors.error.withOpacity(0.8),
                                                                ],
                                                              )
                                                            : LinearGradient(
                                                                colors: [
                                                                  AppColors.success,
                                                                  AppColors.success.withOpacity(0.8),
                                                                ],
                                                              ),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.timer_rounded,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(
                                                            '$timeLeftث',
                                                            style: AppTextStyles.arabicBodySmall.copyWith(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  
                                                  // Fare
                                                  Expanded(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        gradient: AppColors.secondaryGradient,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.payments_rounded,
                                                            size: 16,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Flexible(
                                                            child: Text(
                                                              '$fare',
                                                              style: AppTextStyles.arabicBodySmall.copyWith(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w700,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
