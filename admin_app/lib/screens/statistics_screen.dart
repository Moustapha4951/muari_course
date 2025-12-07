import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      // 1. إحصائيات الرحلات
      final ridesQuery = await FirebaseFirestore.instance.collection('rides').get();
      final totalRides = ridesQuery.size;
      
      int completedRides = 0;
      int pendingRides = 0;
      int cancelledRides = 0;
      int ongoingRides = 0;
      double totalRevenue = 0;
      
      for (var doc in ridesQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        
        if (status == 'completed') {
          completedRides++;
          final fare = (data['fare'] ?? 0).toDouble();
          totalRevenue += fare;
        } else if (status == 'pending') {
          pendingRides++;
        } else if (status == 'cancelled') {
          cancelledRides++;
        } else if (status == 'accepted' || status == 'on_way' || status == 'arrived' || status == 'started') {
          ongoingRides++;
        }
      }

      // 2. إحصائيات السائقين
      final driversQuery = await FirebaseFirestore.instance.collection('drivers').get();
      int onlineDrivers = 0;
      int availableDrivers = 0;
      int busyDrivers = 0;
      int approvedDrivers = 0;
      
      for (var doc in driversQuery.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final isApproved = data['isApproved'] as bool? ?? false;
        
        if (isApproved) approvedDrivers++;
        if (status == 'online') onlineDrivers++;
        if (status == 'available') availableDrivers++;
        if (status == 'busy') busyDrivers++;
      }

      // 3. إحصائيات الزبائن
      final customersQuery = await FirebaseFirestore.instance.collection('customers').get();
      final clientsQuery = await FirebaseFirestore.instance.collection('clients').get();
      final totalCustomers = customersQuery.size + clientsQuery.size;

      // 4. إحصائيات المدن والأماكن
      final citiesQuery = await FirebaseFirestore.instance.collection('cities').get();
      final placesQuery = await FirebaseFirestore.instance.collection('places').get();

      setState(() {
        _stats = {
          'totalRides': totalRides,
          'completedRides': completedRides,
          'pendingRides': pendingRides,
          'cancelledRides': cancelledRides,
          'ongoingRides': ongoingRides,
          'totalRevenue': totalRevenue,
          'totalDrivers': driversQuery.size,
          'onlineDrivers': onlineDrivers,
          'availableDrivers': availableDrivers,
          'busyDrivers': busyDrivers,
          'approvedDrivers': approvedDrivers,
          'totalCustomers': totalCustomers,
          'registeredCustomers': customersQuery.size,
          'adminCustomers': clientsQuery.size,
          'totalCities': citiesQuery.size,
          'totalPlaces': placesQuery.size,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('خطأ في تحميل الإحصائيات: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في تحميل الإحصائيات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'الإحصائيات',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadStatistics,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('إحصائيات الرحلات'),
                    const SizedBox(height: 16),
                    _buildRidesGrid(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('إحصائيات السائقين'),
                    const SizedBox(height: 16),
                    _buildDriversGrid(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('إحصائيات عامة'),
                    const SizedBox(height: 16),
                    _buildGeneralGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.arabicHeadline.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRidesGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          'إجمالي الرحلات',
          '${NumberFormat('#,###').format(_stats['totalRides'] ?? 0)}',
          Icons.local_taxi_rounded,
          AppColors.primary,
        ),
        _buildStatCard(
          'رحلات مكتملة',
          '${NumberFormat('#,###').format(_stats['completedRides'] ?? 0)}',
          Icons.check_circle_rounded,
          AppColors.success,
        ),
        _buildStatCard(
          'رحلات معلقة',
          '${NumberFormat('#,###').format(_stats['pendingRides'] ?? 0)}',
          Icons.pending_rounded,
          AppColors.warning,
        ),
        _buildStatCard(
          'رحلات جارية',
          '${NumberFormat('#,###').format(_stats['ongoingRides'] ?? 0)}',
          Icons.directions_car_rounded,
          AppColors.info,
        ),
        _buildStatCard(
          'رحلات ملغاة',
          '${NumberFormat('#,###').format(_stats['cancelledRides'] ?? 0)}',
          Icons.cancel_rounded,
          AppColors.error,
        ),
        _buildStatCard(
          'إجمالي الإيرادات',
          '${NumberFormat('#,###').format(_stats['totalRevenue'] ?? 0)} MRU',
          Icons.attach_money_rounded,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildDriversGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          'إجمالي السائقين',
          '${NumberFormat('#,###').format(_stats['totalDrivers'] ?? 0)}',
          Icons.people_alt_rounded,
          AppColors.secondary,
        ),
        _buildStatCard(
          'سائقون معتمدون',
          '${NumberFormat('#,###').format(_stats['approvedDrivers'] ?? 0)}',
          Icons.verified_user_rounded,
          AppColors.success,
        ),
        _buildStatCard(
          'سائقون متصلون',
          '${NumberFormat('#,###').format(_stats['onlineDrivers'] ?? 0)}',
          Icons.wifi_rounded,
          Colors.green,
        ),
        _buildStatCard(
          'سائقون متاحون',
          '${NumberFormat('#,###').format(_stats['availableDrivers'] ?? 0)}',
          Icons.check_circle_outline_rounded,
          AppColors.info,
        ),
        _buildStatCard(
          'سائقون مشغولون',
          '${NumberFormat('#,###').format(_stats['busyDrivers'] ?? 0)}',
          Icons.work_rounded,
          AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildGeneralGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _buildStatCard(
          'إجمالي الزبائن',
          '${NumberFormat('#,###').format(_stats['totalCustomers'] ?? 0)}',
          Icons.people_rounded,
          AppColors.primary,
        ),
        _buildStatCard(
          'زبائن مسجلون',
          '${NumberFormat('#,###').format(_stats['registeredCustomers'] ?? 0)}',
          Icons.person_add_rounded,
          AppColors.success,
        ),
        _buildStatCard(
          'زبائن الإدارة',
          '${NumberFormat('#,###').format(_stats['adminCustomers'] ?? 0)}',
          Icons.admin_panel_settings_rounded,
          AppColors.secondary,
        ),
        _buildStatCard(
          'المدن',
          '${NumberFormat('#,###').format(_stats['totalCities'] ?? 0)}',
          Icons.location_city_rounded,
          AppColors.info,
        ),
        _buildStatCard(
          'الأماكن',
          '${NumberFormat('#,###').format(_stats['totalPlaces'] ?? 0)}',
          Icons.place_rounded,
          AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.arabicBody.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
