import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';
import 'customer_details_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _isLoading = true;
  List<QueryDocumentSnapshot> _customers = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      // جلب البيانات من مجموعة customers (من تطبيق الزبائن)
      final customersSnapshot =
          await FirebaseFirestore.instance.collection('customers').get();

      // جلب البيانات من مجموعة clients (من تطبيق الإدارة)
      final clientsSnapshot =
          await FirebaseFirestore.instance.collection('clients').get();

      // دمج النتائج من الكولكشنين مع إضافة معلومة الكولكشن
      final allCustomers = [
        ...customersSnapshot.docs.map((doc) {
          // Add collection name to track source
          return doc;
        }),
        ...clientsSnapshot.docs.map((doc) {
          // Add collection name to track source
          return doc;
        }),
      ];

      debugPrint('تم تحميل ${customersSnapshot.docs.length} زبون من customers');
      debugPrint('تم تحميل ${clientsSnapshot.docs.length} زبون من clients');
      debugPrint('إجمالي: ${allCustomers.length} زبون');

      setState(() {
        _customers = allCustomers;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading customers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ في تحميل بيانات الزبائن')),
        );
      }
    }
  }

  List<QueryDocumentSnapshot> _getFilteredCustomers(String query) {
    if (query.isEmpty) {
      return _customers;
    }
    return _customers.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final phone = data['phone']?.toString().toLowerCase() ?? '';
      final name = data['name']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      return phone.contains(searchQuery) || name.contains(searchQuery);
    }).toList();
  }

  Widget _buildCustomerCard(QueryDocumentSnapshot customer) {
    Map<String, dynamic> data = customer.data() as Map<String, dynamic>;
    Timestamp? createdAt = data['createdAt'] as Timestamp?;
    String formattedDate;

    if (createdAt != null) {
      DateTime date = createdAt.toDate();
      formattedDate = '${date.year}/${date.month}/${date.day}';
    } else {
      formattedDate = 'غير متوفر';
    }

    int completedRides = (data['completedRides'] ?? 0) as int;
    double rating = (data['rating'] ?? 0.0).toDouble();
    bool isBanned = (data['isBanned'] ?? false) as bool;
    String name = (data['name'] ?? 'بدون اسم') as String;
    String phone = (data['phone'] ?? 'بدون رقم') as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBanned ? AppColors.error.withOpacity(0.2) : AppColors.border,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Determine which collection this customer is from
            final collectionName = customer.reference.parent.id;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerDetailsScreen(
                  customerId: customer.id,
                  customerData: Map<String, dynamic>.from(data),
                  collectionName: collectionName,
                ),
              ),
            ).then((_) => _loadCustomers());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'محظور',
                              style: AppTextStyles.arabicCaption.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: AppTextStyles.arabicCaption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.arabicBody.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Container(
                    height: 1,
                    color: AppColors.border,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.local_taxi_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$completedRides رحلة',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = _getFilteredCustomers(_searchController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'قائمة الزبائن',
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
            onPressed: _loadCustomers,
            tooltip: 'تحديث القائمة',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جميع الزبائن',
                        style: AppTextStyles.arabicBodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  style: AppTextStyles.arabicBody,
                  decoration: InputDecoration(
                    hintText: 'البحث عن زبون...',
                    hintStyle: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textHint,
                    ),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  )
                : filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد زبائن',
                              style: AppTextStyles.arabicBody.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: filteredCustomers.length,
                        itemBuilder: (context, index) =>
                            _buildCustomerCard(filteredCustomers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
