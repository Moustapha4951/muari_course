import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/driver.dart';
import '../services/driver_service.dart';
import '../utils/app_theme.dart';

class DriverDetailsScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const DriverDetailsScreen({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<DriverDetailsScreen> createState() => _DriverDetailsScreenState();
}

class _DriverDetailsScreenState extends State<DriverDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DriverService _driverService = DriverService();
  bool _isLoading = false;
  Driver? _driver;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _rides = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDriverDetails();
  }

  Future<void> _loadDriverDetails() async {
    setState(() => _isLoading = true);
    try {
      // تحميل بيانات السائق
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .get();

      if (driverDoc.exists) {
        _driver = Driver.fromFirestore(driverDoc);
      }

      // تحميل المعاملات المالية
      final transactionsQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('driverId', isEqualTo: widget.driverId)
          .orderBy('date', descending: true)
          .limit(50)
          .get();

      _transactions = transactionsQuery.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // تحميل الرحلات
      final ridesQuery = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: widget.driverId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      _rides =
          ridesQuery.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('حدث خطأ في تحميل البيانات: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _toggleBanStatus() async {
    if (_driver == null) return;

    try {
      await _driverService.toggleDriverBan(widget.driverId, !_driver!.isBanned);
      _showSuccessSnackBar(
          _driver!.isBanned ? 'تم إلغاء حظر السائق' : 'تم حظر السائق');
      await _loadDriverDetails();
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _driver == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: Text(
            'تفاصيل السائق',
            style: AppTextStyles.arabicTitle.copyWith(
              color: AppColors.surface,
            ),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          _driver!.name,
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.surface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _driver!.isBanned ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: AppColors.surface,
            ),
            onPressed: _toggleBanStatus,
            tooltip: _driver!.isBanned ? 'إلغاء الحظر' : 'حظر',
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.surface),
            onPressed: _loadDriverDetails,
            tooltip: 'تحديث',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.surface,
          unselectedLabelColor: AppColors.surface.withOpacity(0.7),
          indicatorColor: AppColors.surface,
          tabs: [
            Tab(
              child: Text(
                'المعلومات',
                style: AppTextStyles.arabicBody,
              ),
            ),
            Tab(
              child: Text(
                'المعاملات',
                style: AppTextStyles.arabicBody,
              ),
            ),
            Tab(
              child: Text(
                'الرحلات',
                style: AppTextStyles.arabicBody,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildTransactionsTab(),
          _buildRidesTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildPersonalInfoCard(),
          const SizedBox(height: 16),
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الحالة',
            style: AppTextStyles.arabicTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                'الحساب',
                _driver!.isApproved ? 'معتمد' : 'قيد المراجعة',
                _driver!.isApproved ? Colors.green : Colors.orange,
              ),
              _buildStatusItem(
                'الاتصال',
                _driver!.status == 'online' ? 'متصل' : 'غير متصل',
                _driver!.status == 'online' ? Colors.green : Colors.grey,
              ),
              _buildStatusItem(
                'الحظر',
                _driver!.isBanned ? 'محظور' : 'نشط',
                _driver!.isBanned ? Colors.red : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.arabicBodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'المعلومات الشخصية',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('الاسم', _driver!.name),
            _buildInfoRow('رقم الهاتف', _driver!.phone),
            _buildInfoRow('المدينة', _driver!.city),
            _buildInfoRow(
              'تاريخ التسجيل',
              _driver!.createdAt != null
                  ? DateFormat('yyyy/MM/dd').format(_driver!.createdAt!)
                  : 'غير متوفر',
            ),
            _buildInfoRow(
              'التقييم',
              '${_driver!.rating.toStringAsFixed(1)} ⭐',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.arabicBody.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.arabicBody.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الإحصائيات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'الرصيد الحالي',
                    '${_driver!.balance.toStringAsFixed(2)} MRU',
                    _driver!.balance > 0 ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    'عدد الرحلات',
                    _driver!.completedRides.length.toString(),
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.arabicTitle.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          'لا توجد معاملات مالية',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _transactions.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final transaction = _transactions[index];
        final amount = (transaction['amount'] as num).toDouble();
        final date = (transaction['date'] as Timestamp).toDate();
        final type = transaction['type'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (type == 'deposit' ? AppColors.success : AppColors.error)
                      .withOpacity(0.1),
              radius: 24,
              child: Icon(
                type == 'deposit'
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: type == 'deposit' ? AppColors.success : AppColors.error,
                size: 24,
              ),
            ),
            title: Text(
              type == 'deposit' ? 'إيداع' : 'سحب',
              style: AppTextStyles.arabicBody.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['reason'] ?? '',
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(date),
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: Text(
              '${type == 'deposit' ? '+' : '-'}${amount.toStringAsFixed(2)} MRU',
              style: AppTextStyles.arabicBody.copyWith(
                color: type == 'deposit' ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRidesTab() {
    if (_rides.isEmpty) {
      return Center(
        child: Text(
          'لا توجد رحلات',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _rides.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ride = _rides[index];
        final status = ride['status'] as String;
        final createdAt = (ride['createdAt'] as Timestamp).toDate();
        final fare = (ride['fare'] as num?)?.toDouble() ?? 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: _buildRideStatusIcon(status),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    '${ride['customerName'] ?? 'زبون'}',
                    style: AppTextStyles.arabicBody.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$fare MRU',
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'من: ${ride['pickupLocation']?['name'] ?? 'غير محدد'}\n'
                  'إلى: ${ride['dropoffLocation']?['name'] ?? 'غير محدد'}',
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  DateFormat('yyyy/MM/dd HH:mm').format(createdAt),
                  style: AppTextStyles.arabicBodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRideStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'completed':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        break;
      case 'cancelled':
        icon = Icons.cancel_rounded;
        color = AppColors.error;
        break;
      case 'pending':
        icon = Icons.access_time_rounded;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.info_rounded;
        color = AppColors.textSecondary;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      radius: 24,
      child: Icon(icon, color: color, size: 24),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
