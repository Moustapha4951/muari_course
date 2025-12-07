import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;
import 'ride_details_screen.dart';
import 'dart:async';
import 'dart:math' show min;
import '../utils/app_theme.dart';

class RidesScreen extends StatefulWidget {
  const RidesScreen({super.key});

  @override
  State<RidesScreen> createState() => _RidesScreenState();
}

class _RidesScreenState extends State<RidesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeRides = [];
  Timer? _refreshTimer;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredActiveRides = [];
  String _selectedFilter = 'all';

  int _itemsPerPage = 100;
  int _currentPage = 0;
  bool _hasMoreItems = true;
  bool _isLoadingMore = false;
  ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadRides();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _loadRides());
    _searchController.addListener(_filterRides);
    _scrollController.addListener(_scrollListener);
  }

  void _filterRides() {
    final query = _searchController.text.trim().toLowerCase();

    debugPrint('تتم الفلترة باستخدام: "$query" - الفلتر: $_selectedFilter');

    setState(() {
      if (query.isEmpty && _selectedFilter == 'all') {
        _filteredActiveRides = List.from(_activeRides);
      } else {
        _filteredActiveRides = _activeRides.where((ride) {
          String customerPhone =
              (ride['customerPhone'] ?? '').toString().toLowerCase();
          String driverPhone =
              (ride['driverPhone'] ?? '').toString().toLowerCase();

          customerPhone = _normalizePhoneNumber(customerPhone);
          driverPhone = _normalizePhoneNumber(driverPhone);

          String normalizedQuery = _normalizePhoneNumber(query);

          bool phoneMatch = customerPhone.contains(normalizedQuery) ||
              driverPhone.contains(normalizedQuery);

          String index = (ride['index'] ?? '').toString();
          String customerName =
              (ride['customerName'] ?? '').toString().toLowerCase();
          String driverName =
              (ride['driverName'] ?? '').toString().toLowerCase();
          String pickupAddress =
              (ride['pickupAddress'] ?? '').toString().toLowerCase();

          String rideId = (ride['id'] ?? '').toString().toLowerCase();

          bool matchesSearch = query.isEmpty ||
              phoneMatch ||
              index == query ||
              customerName.contains(query) ||
              driverName.contains(query) ||
              pickupAddress.contains(query) ||
              rideId.contains(query);

          if (query.isNotEmpty &&
              (customerPhone.contains(normalizedQuery) ||
                  driverPhone.contains(normalizedQuery))) {
            debugPrint(
                'تم العثور على مطابقة للرقم: CP=$customerPhone, DP=$driverPhone, Q=$normalizedQuery');
          }

          bool matchesFilter =
              _selectedFilter == 'all' || ride['status'] == _selectedFilter;

          return matchesSearch && matchesFilter;
        }).toList();
      }

      _currentPage = 0;
      _hasMoreItems = _filteredActiveRides.length > _itemsPerPage;
    });
  }

  String _normalizePhoneNumber(String phone) {
    return phone
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('+', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .trim();
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      final lastRideDoc = await FirebaseFirestore.instance
          .collection('rides')
          .orderBy('index', descending: true)
          .limit(1)
          .get();

      final lastIndex = lastRideDoc.docs.isEmpty
          ? 0
          : lastRideDoc.docs.first.data()['index'] ?? 0;

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final timestampThirtyDaysAgo = Timestamp.fromDate(thirtyDaysAgo);

      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('createdAt', isGreaterThan: timestampThirtyDaysAgo)
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        for (var doc in ridesSnapshot.docs) {
          final data = doc.data();
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          if (data['status'] == 'pending' &&
              now.difference(createdAt).inSeconds > 30) {
            await doc.reference.update({
              'status': 'timeout',
              'index': lastIndex + 1,
            });
            data['status'] = 'timeout';
            data['index'] = lastIndex + 1;
          }
        }

        List<Map<String, dynamic>> processedRides = [];

        for (var doc in ridesSnapshot.docs) {
          Map<String, dynamic> rideData = {...doc.data(), 'id': doc.id};

          if (rideData.containsKey('customerPhone')) {
            String phone = rideData['customerPhone'].toString();
            rideData['customerPhone'] = phone.trim();
          }

          if (rideData.containsKey('driverPhone')) {
            String phone = rideData['driverPhone'].toString();
            rideData['driverPhone'] = phone.trim();
          }

          if (rideData.containsKey('fare') && rideData['fare'] != null) {
            if (rideData['fare'] is int) {
              rideData['fare'] = (rideData['fare'] as int).toDouble();
            } else if (rideData['fare'] is String) {
              rideData['fare'] = double.tryParse(rideData['fare']) ?? 0.0;
            }
          }

          processedRides.add(rideData);
        }

        setState(() {
          _activeRides = processedRides;

          _activeRides
              .sort((a, b) => (b['index'] ?? 0).compareTo(a['index'] ?? 0));

          _filterRides();
          _isLoading = false;
        });

        for (int i = 0; i < min(5, _activeRides.length); i++) {
          debugPrint('هاتف عميل #$i: ${_activeRides[i]['customerPhone']}');
          debugPrint('هاتف سائق #$i: ${_activeRides[i]['driverPhone']}');
        }
      }
    } catch (e) {
      debugPrint('خطأ في تحميل الرحلات: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الرحلات: $e')),
        );
      }
    }
  }

  Future<void> _resendRide(Map<String, dynamic> ride) async {
    setState(() => _isLoading = true);

    try {
      final ridesRef = FirebaseFirestore.instance.collection('rides');

      Map<String, dynamic> newRideData = {
        'customerName': ride['customerName'],
        'customerPhone': ride['customerPhone'],
        'pickupAddress': ride['pickupAddress'],
        'dropoffAddress': ride['dropoffAddress'],
        'pickupLocation': ride['pickupLocation'],
        'dropoffLocation': ride['dropoffLocation'],
        'fare': ride['fare'],
        'distance': ride['distance'],
        'duration': ride['duration'],
        'isOpenRide': ride['isOpenRide'] ?? false,
        'city': ride['city'] ?? 'نواكشوط',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (ride['priceId'] != null) newRideData['priceId'] = ride['priceId'];
      if (ride['priceDetails'] != null)
        newRideData['priceDetails'] = ride['priceDetails'];
      if (ride['paymentMethod'] != null)
        newRideData['paymentMethod'] = ride['paymentMethod'];

      final lastRideDoc =
          await ridesRef.orderBy('index', descending: true).limit(1).get();
      final lastIndex = lastRideDoc.docs.isEmpty
          ? 0
          : lastRideDoc.docs.first.data()['index'] ?? 0;
      newRideData['index'] = lastIndex + 1;

      debugPrint('إعادة إرسال رحلة جديدة بالمعلومات:');
      debugPrint('المدينة: ${newRideData['city']}');
      debugPrint('العميل: ${newRideData['customerName']}');
      debugPrint('الحالة: ${newRideData['status']}');

      final docRef = await ridesRef.add(newRideData);

      debugPrint('تم إنشاء رحلة جديدة بنجاح! المعرف: ${docRef.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعادة إرسال الرحلة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      _loadRides();
    } catch (e) {
      debugPrint('خطأ في إعادة إرسال الرحلة: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إعادة إرسال الرحلة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير متوفر';
    return _formatDateTime(timestamp.toDate());
  }

  String _getElapsedTime(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'منذ ${difference.inSeconds} ثانية';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return 'منذ ${difference.inDays} يوم';
    }
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final status = ride['status'] as String;
    final statusText = {
          'pending': 'في الانتظار',
          'accepted': 'تم القبول',
          'started': 'جارية',
          'completed': 'مكتملة',
          'cancelled': 'ملغية',
          'timeout': 'منتهية المدة',
          'paused': 'متوقفة مؤقتاً',
        }[status] ??
        status;

    final statusColor = {
          'pending': AppColors.warning,
          'accepted': AppColors.info,
          'started': AppColors.secondary,
          'completed': AppColors.success,
          'cancelled': AppColors.error,
          'timeout': AppColors.textSecondary,
          'paused': AppColors.warning,
        }[status] ??
        AppColors.textSecondary;

    final fare = ride['fare'] is int
        ? (ride['fare'] as int).toDouble()
        : (ride['fare'] as num?)?.toDouble() ?? 0.0;

    final elapsedTime = _getElapsedTime(ride['createdAt'] as Timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideDetailsScreen(rideData: ride),
            ),
          ).then((_) => _loadRides());
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '#${ride['index'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        elapsedTime,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatTimestamp(ride['createdAt']),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'السعر',
                        style: AppTextStyles.arabicBodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${intl.NumberFormat('#,##0.00', 'ar').format(fare)} MRU',
                        style: AppTextStyles.arabicTitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ride['customerName'] ?? 'غير متوفر',
                                style: AppTextStyles.arabicBody.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              color: AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ride['customerPhone'] ?? 'غير متوفر',
                              style: AppTextStyles.arabicBodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (ride['duration'] != null)
                    Row(
                      children: [
                        Icon(
                          Icons.timer_rounded,
                          color: AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ride['duration'].toStringAsFixed(0)} دقيقة',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  if (ride['distance'] != null)
                    Row(
                      children: [
                        Icon(
                          Icons.straight_rounded,
                          color: AppColors.info,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ride['distance'].toStringAsFixed(1)} كم',
                          style: AppTextStyles.arabicBodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride['pickupAddress'] ?? 'غير متوفر',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride['dropoffAddress'] ?? 'غير متوفر',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (ride['driverName'] != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(Icons.drive_eta_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'السائق: ${ride['driverName']}',
                            style: AppTextStyles.arabicBody.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            ride['driverPhone'] ?? '',
                            style: AppTextStyles.arabicBodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (status == 'timeout' || status == 'cancelled') ...[
                const Divider(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _resendRide(ride),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة إرسال الرحلة'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: AppColors.surface,
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'إدارة الرحلات',
          style: AppTextStyles.arabicTitle.copyWith(
            color: AppColors.surface,
          ),
        ),
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.file_download, color: AppColors.surface),
            tooltip: 'تصدير إلى Excel',
            onPressed: _exportToExcel,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: 'بحث برقم الهاتف أو الاسم...',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: Icon(Icons.search, color: AppColors.surface),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppColors.surface),
                            onPressed: () {
                              _searchController.clear();
                              _filterRides();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    hintStyle: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.surface.withOpacity(0.7),
                    ),
                  ),
                  style: AppTextStyles.arabicBody.copyWith(
                    color: AppColors.surface,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل', 'all'),
                      _buildFilterChip('في الانتظار', 'pending'),
                      _buildFilterChip('تم القبول', 'accepted'),
                      _buildFilterChip('جارية', 'started'),
                      _buildFilterChip('مكتملة', 'completed'),
                      _buildFilterChip('ملغية', 'cancelled'),
                      _buildFilterChip('منتهية المدة', 'timeout'),
                      _buildFilterChip('متوقفة', 'paused'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRides,
              child: _filteredActiveRides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.route,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد رحلات مطابقة',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'عدد الرحلات: ${_filteredActiveRides.length}',
                                  style: AppTextStyles.arabicBodySmall.copyWith(
                                    color: AppColors.surface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _filteredActiveRides.length + 1,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              if (index < _filteredActiveRides.length) {
                                return _buildRideCard(
                                    _filteredActiveRides[index]);
                              } else {
                                return _buildLoadingIndicator();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRides,
        backgroundColor: AppColors.primary,
        child: Icon(Icons.refresh, color: AppColors.surface),
        elevation: 4,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = value;
            _filterRides();
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.surface
                : AppColors.surface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.surface.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.arabicBodySmall.copyWith(
              color: isSelected ? AppColors.primary : AppColors.surface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRides();
    }
  }

  Future<void> _loadMoreRides() async {
    if (!_hasMoreItems || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;
      final startIndex = _currentPage * _itemsPerPage;

      if (startIndex >= _activeRides.length) {
        setState(() {
          _hasMoreItems = false;
          _isLoadingMore = false;
        });
        return;
      }

      final itemsToShow = _filteredActiveRides.length;
      setState(() {
        _isLoadingMore = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحميل $itemsToShow رحلة'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: _hasMoreItems
            ? const CircularProgressIndicator()
            : const Text("لا توجد المزيد من الرحلات"),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري إعداد ملف Excel...')),
      );

      List<Map<String, dynamic>> exportData = [];

      for (var ride in _filteredActiveRides) {
        exportData.add({
          'رقم التسلسل': ride['index'] ?? '',
          'الحالة': _getStatusName(ride['status'] ?? ''),
          'اسم الزبون': ride['customerName'] ?? '',
          'رقم الزبون': ride['customerPhone'] ?? '',
          'اسم السائق': ride['driverName'] ?? '',
          'رقم السائق': ride['driverPhone'] ?? '',
          'موقع الانطلاق': ride['pickupAddress'] ?? '',
          'موقع الوصول': ride['dropoffAddress'] ?? '',
          'التكلفة': ride['fare'] ?? '',
          'تاريخ الإنشاء': _formatTimestamp(ride['createdAt']),
          'نوع الرحلة': ride['isOpenRide'] == true ? 'مفتوحة' : 'عادية',
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير البيانات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تصدير البيانات: $e')),
      );
    }
  }

  String _getStatusName(String status) {
    switch (status) {
      case 'pending':
        return 'في الانتظار';
      case 'accepted':
        return 'تم القبول';
      case 'on_way':
        return 'في الطريق';
      case 'started':
        return 'جارية';
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغية';
      case 'timeout':
        return 'منتهية المدة';
      case 'paused':
        return 'متوقفة';
      default:
        return status;
    }
  }
}
