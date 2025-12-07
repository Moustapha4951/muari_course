import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import '../utils/shared_preferences_helper.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _customerId;
  List<Map<String, dynamic>> _rideHistory = [];
  bool _isLoading = true;
  double _totalSpent = 0.0;
  int _completedRides = 0;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    
    try {
      final userData = await SharedPreferencesHelper.getUserData();
      _customerId = userData['userId'];

      if (_customerId != null) {
        // Get completed rides
        final ridesSnapshot = await FirebaseFirestore.instance
            .collection('rides')
            .where('customerId', isEqualTo: _customerId)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
            .limit(50)
            .get();

        _rideHistory = ridesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        // Calculate total spent
        _totalSpent = _rideHistory.fold(0.0, (sum, ride) {
          return sum + ((ride['fare'] ?? 0.0) as num).toDouble();
        });

        _completedRides = _rideHistory.length;
      }
    } catch (e) {
      debugPrint('Error loading wallet data: $e');
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
        title: Text('المحفظة', style: AppTextStyles.arabicTitle),
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
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
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
                          Text(
                            'إجمالي المصروفات',
                            style: AppTextStyles.arabicBody.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_totalSpent.toStringAsFixed(2)} MRU',
                            style: AppTextStyles.arabicTitle.copyWith(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.white30),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                icon: Icons.check_circle_rounded,
                                label: 'رحلات مكتملة',
                                value: '$_completedRides',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white30,
                              ),
                              _buildStatItem(
                                icon: Icons.attach_money_rounded,
                                label: 'متوسط السعر',
                                value: _completedRides > 0
                                    ? '${(_totalSpent / _completedRides).toStringAsFixed(0)} MRU'
                                    : '0 MRU',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ride History Title
                    Text(
                      'سجل الرحلات',
                      style: AppTextStyles.arabicTitle.copyWith(
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ride History List
                    if (_rideHistory.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                size: 64,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد رحلات مكتملة',
                                style: AppTextStyles.arabicBody.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._rideHistory.map((ride) => _buildRideCard(ride)).toList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.arabicTitle.copyWith(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.arabicCaption.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final fare = ((ride['fare'] ?? 0.0) as num).toDouble();
    final distance = ((ride['distance'] ?? 0.0) as num).toDouble();
    final pickupAddress = ride['pickupAddress'] ?? 'غير محدد';
    final dropoffAddress = ride['dropoffAddress'] ?? 'غير محدد';
    final isOpen = ride['isOpen'] ?? false;
    final completedAt = ride['completedAt'] as Timestamp?;
    
    String dateStr = 'غير محدد';
    if (completedAt != null) {
      final date = completedAt.toDate();
      dateStr = '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOpen ? AppColors.warning.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isOpen ? Icons.explore_rounded : Icons.local_taxi_rounded,
                      color: isOpen ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isOpen ? 'رحلة مفتوحة' : 'رحلة عادية',
                    style: AppTextStyles.arabicBody.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${fare.toStringAsFixed(2)} MRU',
                style: AppTextStyles.arabicTitle.copyWith(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickupAddress,
                  style: AppTextStyles.arabicBodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (!isOpen) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropoffAddress,
                    style: AppTextStyles.arabicBodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.route_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} كم',
                    style: AppTextStyles.arabicCaption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                dateStr,
                style: AppTextStyles.arabicCaption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
