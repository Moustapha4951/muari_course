import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_admin/screens/driver_details_screen.dart';
import '../models/driver.dart';
import '../services/driver_service.dart';
import '../utils/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  final DriverService _driverService = DriverService();
  bool _isLoading = true;
  List<Driver> _drivers = [];
  List<Driver> _filteredDrivers = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  String _filterStatus = 'all'; // 'all', 'online', 'offline'
  String _sortBy = 'name'; // 'name', 'balance', 'date'
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final drivers = await _driverService.getAllDrivers();
      if (mounted) {
        setState(() {
          _drivers = drivers;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('حدث خطأ في تحميل بيانات السائقين: $e');
      }
    }
  }

  void _applyFilters() {
    List<Driver> filtered = List.from(_drivers);

    // تطبيق البحث
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((driver) {
        return driver.name.toLowerCase().contains(query) ||
            driver.phone.toLowerCase().contains(query);
      }).toList();
    }

    // تطبيق فلتر الحالة
    if (_filterStatus == 'pending') {
      filtered = filtered.where((driver) => !driver.isApproved).toList();
    } else if (_filterStatus != 'all') {
      filtered =
          filtered.where((driver) => driver.status == _filterStatus).toList();
    }

    // تطبيق الترتيب
    filtered.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'balance':
          comparison = a.balance.compareTo(b.balance);
          break;
        case 'date':
          comparison = (a.createdAt ?? DateTime.now())
              .compareTo(b.createdAt ?? DateTime.now());
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() => _filteredDrivers = filtered);
  }

  Future<void> _confirmDeleteDriver(Driver driver) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
            'هل أنت متأكد من حذف السائق ${driver.name}؟\nهذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(driver.id)
                    .delete();
                _showSuccessSnackBar('تم حذف السائق بنجاح');
                await _loadDrivers();
              } catch (e) {
                _showErrorSnackBar('حدث خطأ في حذف السائق: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeductBalanceDialog(Driver driver) async {
    _amountController.clear();
    _reasonController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خصم رصيد ${driver.name}', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'السبب',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('خصم الرصيد'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deductBalance(driver);
    }
  }

  Future<void> _deductBalance(Driver driver) async {
    if (_amountController.text.isEmpty || _reasonController.text.isEmpty) {
      _showErrorSnackBar('يرجى إدخال المبلغ والسبب');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('يرجى إدخال مبلغ صحيح');
      return;
    }

    if (amount > driver.balance) {
      _showErrorSnackBar('المبلغ المطلوب خصمه أكبر من رصيد السائق');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // تحديث رصيد السائق
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driver.id)
          .update({
        'balance': FieldValue.increment(-amount),
      });

      // إضافة المعاملة
      await FirebaseFirestore.instance.collection('transactions').add({
        'driverId': driver.id,
        'driverName': driver.name,
        'amount': amount,
        'type': 'withdrawal',
        'reason': _reasonController.text,
        'date': FieldValue.serverTimestamp(),
        'balance': driver.balance - amount,
        'adminNote': 'تم الخصم من لوحة التحكم',
      });

      _showSuccessSnackBar('تم خصم $amount من رصيد ${driver.name} بنجاح');
      await _loadDrivers();
    } catch (e) {
      _showErrorSnackBar('خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddBalanceDialog(Driver driver) async {
    _amountController.clear();
    _reasonController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('شحن رصيد ${driver.name}', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'السبب',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.right,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('شحن الرصيد'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _addBalance(driver);
    }
  }

  Future<void> _approveDriver(String driverId) async {
    try {
      await _driverService.approveDriver(driverId);
      _showSuccessSnackBar('تم قبول السائق بنجاح');
      await _loadDrivers();
    } catch (e) {
      _showErrorSnackBar('حدث خطأ في قبول السائق: $e');
    }
  }

  Future<void> _rejectDriver(String driverId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الرفض'),
        content: const Text('هل أنت متأكد من رفض هذا السائق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                // حذف السائق من قاعدة البيانات
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(driverId)
                    .delete();
                _showSuccessSnackBar('تم رفض السائق بنجاح');
                await _loadDrivers();
              } catch (e) {
                _showErrorSnackBar('حدث خطأ في رفض السائق: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBalance(Driver driver) async {
    if (_amountController.text.isEmpty || _reasonController.text.isEmpty) {
      _showErrorSnackBar('يرجى إدخال المبلغ والسبب');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorSnackBar('يرجى إدخال مبلغ صحيح');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _driverService.addBalance(
        driver.id,
        driver.name,
        amount,
        _reasonController.text,
      );

      _showSuccessSnackBar('تم إضافة $amount إلى رصيد ${driver.name} بنجاح');
      await _loadDrivers();
    } catch (e) {
      _showErrorSnackBar('خطأ: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToDriverDetails(Driver driver) async {
    final needsRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DriverDetailsScreen(
          driverId: driver.id,
          driverData: driver.toMap(),
        ),
      ),
    );

    if (needsRefresh == true) {
      await _loadDrivers();
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'فلترة وترتيب',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 16),
              // حالة السائق
              DropdownButton<String>(
                isExpanded: true,
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('جميع السائقين')),
                  DropdownMenuItem(
                      value: 'pending', child: Text('قيد المراجعة')),
                  DropdownMenuItem(value: 'online', child: Text('المتصلين')),
                  DropdownMenuItem(
                      value: 'offline', child: Text('غير المتصلين')),
                ],
                onChanged: (value) {
                  setState(() => _filterStatus = value!);
                  _applyFilters();
                },
              ),
              const SizedBox(height: 8),
              // الترتيب
              DropdownButton<String>(
                isExpanded: true,
                value: _sortBy,
                items: const [
                  DropdownMenuItem(
                      value: 'name', child: Text('الترتيب حسب الاسم')),
                  DropdownMenuItem(
                      value: 'balance', child: Text('الترتيب حسب الرصيد')),
                  DropdownMenuItem(
                      value: 'date', child: Text('الترتيب حسب تاريخ التسجيل')),
                ],
                onChanged: (value) {
                  setState(() => _sortBy = value!);
                  _applyFilters();
                },
              ),
              // اتجاه الترتيب
              SwitchListTile(
                value: _sortAscending,
                onChanged: (value) {
                  setState(() => _sortAscending = value);
                  _applyFilters();
                },
                title: const Text('ترتيب تصاعدي'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _driverService.createTestDriver();
          _showSuccessSnackBar('تم إنشاء سائق اختباري');
          await _loadDrivers();
        },
        backgroundColor: AppColors.primary,
        child: Icon(Icons.add_rounded, color: AppColors.surface),
        elevation: 4,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'إدارة السائقين',
        style: AppTextStyles.arabicTitle.copyWith(
          color: AppColors.surface,
        ),
      ),
      backgroundColor: AppColors.primary,
      centerTitle: true,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(Icons.filter_list_rounded, color: AppColors.surface),
          onPressed: _showFilterSheet,
          tooltip: 'فلترة وترتيب',
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: AppColors.surface),
          onPressed: _loadDrivers,
          tooltip: 'تحديث',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildStatistics(),
        Expanded(
          child: _filteredDrivers.isEmpty
              ? _buildEmptyState()
              : _buildDriversList(),
        ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(8),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'بحث بالاسم أو رقم الهاتف',
          hintStyle: AppTextStyles.arabicBody.copyWith(
            color: AppColors.textSecondary,
          ),
          prefixIcon:
              Icon(Icons.search_rounded, color: AppColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          filled: true,
          fillColor: AppColors.surface,
        ),
        onChanged: (value) => _applyFilters(),
        textAlign: TextAlign.right,
        style: AppTextStyles.arabicBody.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    final approvedCount = _drivers.where((d) => d.isApproved).length;
    final pendingCount = _drivers.length - approvedCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildStatCard(
            'السائقون المعتمدون',
            approvedCount.toString(),
            Colors.green,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'قيد المراجعة',
            pendingCount.toString(),
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
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
              count,
              style: AppTextStyles.arabicTitle.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              title,
              style: AppTextStyles.arabicBodySmall.copyWith(
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سائقين',
            style: AppTextStyles.arabicTitle.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: ListView.builder(
        itemCount: _filteredDrivers.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (context, index) =>
            _buildDriverCard(_filteredDrivers[index]),
      ),
    );
  }

  Widget _buildDriverCard(Driver driver) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap:
            driver.isApproved ? () => _navigateToDriverDetails(driver) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          driver.name,
                          style: AppTextStyles.arabicBody.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driver.phone,
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusBadge(driver),
                ],
              ),
              const Divider(height: 24),
              // Show approval buttons for unapproved drivers
              if (!driver.isApproved) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectDriver(driver.id),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('رفض'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.surface,
                          backgroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToDriverDetails(driver),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('تفاصيل'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          backgroundColor: AppColors.surfaceVariant,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveDriver(driver.id),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('قبول'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: AppColors.surface,
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAddBalanceDialog(driver),
                            icon: const Icon(Icons.add_circle, size: 16),
                            label: const Text('شحن'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: AppColors.surface,
                              backgroundColor: AppColors.success,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDeductBalanceDialog(driver),
                            icon: const Icon(Icons.remove_circle, size: 16),
                            label: const Text('خصم'),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: AppColors.surface,
                              backgroundColor: AppColors.warning,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _confirmDeleteDriver(driver),
                          icon: Icon(Icons.delete_forever_rounded),
                          color: AppColors.error,
                          tooltip: 'حذف السائق',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الرصيد: ${driver.balance.toStringAsFixed(2)} MRU',
                      style: AppTextStyles.arabicBody.copyWith(
                        color: driver.balance > 0
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Driver driver) {
    Color color;
    String text;

    if (!driver.isApproved) {
      color = AppColors.warning;
      text = 'قيد المراجعة';
    } else if (driver.isBanned) {
      color = AppColors.error;
      text = 'محظور';
    } else if (driver.status == 'online') {
      color = AppColors.success;
      text = 'متصل';
    } else {
      color = AppColors.textSecondary;
      text = 'غير متصل';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: AppTextStyles.arabicBodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}
