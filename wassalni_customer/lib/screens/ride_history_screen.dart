import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  String? _customerId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomerId();
  }

  Future<void> _loadCustomerId() async {
    final userId = await SharedPreferencesHelper.getUserId();
    setState(() {
      _customerId = userId;
      _isLoading = false;
    });
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final formatter = intl.DateFormat('dd/MM/yyyy - HH:mm', 'ar');
    return formatter.format(date);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'started':
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      case 'started':
        return 'جارية';
      case 'accepted':
        return 'مقبولة';
      case 'pending':
        return 'قيد الانتظار';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'سجل الرحلات',
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
          : _customerId == null
              ? _buildErrorState()
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .where('customerId', isEqualTo: _customerId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorState();
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      );
                    }

                    final rides = snapshot.data?.docs ?? [];

                    if (rides.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rides.length,
                      itemBuilder: (context, index) {
                        final ride = rides[index].data() as Map<String, dynamic>;
                        final rideId = rides[index].id;
                        return _buildRideCard(ride, rideId);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, String rideId) {
    final status = ride['status'] ?? '';
    final pickupAddress = ride['pickupAddress'] ?? 'غير محدد';
    final dropoffAddress = ride['dropoffAddress'] ?? 'غير محدد';
    final fare = ride['fare']?.toDouble() ?? 0.0;
    final createdAt = ride['createdAt'] as Timestamp?;
    final driverName = ride['driverName'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Header with status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: AppTextStyles.arabicBodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(createdAt),
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Ride details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Pickup
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.my_location_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'من',
                            style: AppTextStyles.arabicCaption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            pickupAddress,
                            style: AppTextStyles.arabicBody.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Dropoff
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إلى',
                            style: AppTextStyles.arabicCaption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            dropoffAddress,
                            style: AppTextStyles.arabicBody.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.border),
                const SizedBox(height: 16),

                // Footer with driver and fare
                Row(
                  children: [
                    if (driverName != null) ...[
                      Icon(
                        Icons.person_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        driverName,
                        style: AppTextStyles.arabicBody.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fare.toStringAsFixed(2)} MRU',
                            style: AppTextStyles.arabicBody.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد رحلات سابقة',
            style: AppTextStyles.arabicTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ رحلتك الأولى الآن',
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
            'تعذر تحميل سجل الرحلات',
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
