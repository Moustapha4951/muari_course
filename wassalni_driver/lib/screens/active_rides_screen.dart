import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/sharedpreferences_helper.dart';
import '../utils/app_theme.dart';
import 'ride_screen_new_version.dart';
import 'open_ride_screen_v2.dart';

class ActiveRidesScreen extends StatefulWidget {
  const ActiveRidesScreen({super.key});

  @override
  State<ActiveRidesScreen> createState() => _ActiveRidesScreenState();
}

class _ActiveRidesScreenState extends State<ActiveRidesScreen> {
  List<Map<String, dynamic>> _activeRides = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveRides();
  }

  Future<void> _loadActiveRides() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      if (driverData['driverId'] == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // جلب الرحلات النشطة (المقبولة والجارية)
      final snapshots = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverData['driverId'])
          .where('status', whereIn: ['accepted', 'started', 'paused'])
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshots.docs.isEmpty) {
        setState(() {
          _activeRides = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _activeRides = snapshots.docs.map((doc) {
          final data = doc.data();
          return {...data, 'id': doc.id};
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading active rides: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل البيانات: $e')),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':
        return 'مقبولة';
      case 'started':
        return 'قيد التنفيذ';
      case 'paused':
        return 'متوقفة مؤقتاً';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppColors.info;
      case 'started':
        return AppColors.warning;
      case 'paused':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final createdAt = timestamp.toDate();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return DateFormat('yyyy/MM/dd - HH:mm').format(createdAt);
    }
  }

  void _openRideScreen(Map<String, dynamic> rideData, String rideId) {
    final bool isOpenRide = rideData['isOpenRide'] == true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isOpenRide
            ? OpenRideScreenV2(
                rideData: rideData,
                rideId: rideId,
              )
            : RideScreenNewVersion(
                rideData: rideData,
                rideId: rideId,
              ),
      ),
    ).then((_) => _loadActiveRides());
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
                            Icons.directions_car_rounded,
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
                            onPressed: _loadActiveRides,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'الرحلات النشطة',
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
                      : RefreshIndicator(
                          onRefresh: _loadActiveRides,
                          color: AppColors.primary,
                          child: _activeRides.isEmpty ? _buildEmptyState() : _buildRidesList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.directions_car_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد رحلات نشطة',
            style: AppTextStyles.arabicTitle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'حالياً',
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _activeRides.length,
      itemBuilder: (context, index) {
        final ride = _activeRides[index];
        final status = ride['status'] as String;
        final rideId = ride['id'] as String;
        final Timestamp? createdAt = ride['createdAt'] as Timestamp?;
        final fare = ride['fare'] is int
            ? (ride['fare'] as int).toDouble()
            : (ride['fare'] as num?)?.toDouble() ?? 0.0;

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
              onTap: () => _openRideScreen(ride, rideId),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatusBadge(status),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeAgo(createdAt),
                                style: AppTextStyles.arabicBodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAddressInfo(ride),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppColors.secondaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.payments_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$fare MRU',
                                style: AppTextStyles.arabicBody.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _openRideScreen(ride, rideId),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      status == 'accepted' ? Icons.play_arrow_rounded : Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      status == 'accepted' ? 'بدء الرحلة' : 'متابعة',
                                      style: AppTextStyles.arabicBody.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ),
        );
      },
    );
  }

  Widget _buildAddressInfo(Map<String, dynamic> ride) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ride['customerName'] ?? 'زبون'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.person,
                color: Color(0xFF2E3F51),
                size: 20,
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  ride['pickupAddress'] ?? 'غير متوفر',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(
              Icons.more_vert,
              color: Colors.grey,
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  ride['dropoffAddress'] ?? 'غير متوفر',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.flag,
                color: Colors.red,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
