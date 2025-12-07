import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';

class CompletedRidesScreen extends StatefulWidget {
  const CompletedRidesScreen({super.key});

  @override
  State<CompletedRidesScreen> createState() => _CompletedRidesScreenState();
}

class _CompletedRidesScreenState extends State<CompletedRidesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _rides = [];
  List<Map<String, dynamic>> _filteredRides = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _selectedPeriod = 'الكل';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _limit = 20;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadRides();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_isLoadingMore) {
      _loadMoreRides();
    }
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentFilter = 'all';
            break;
          case 1:
            _currentFilter = 'completed';
            break;
          case 2:
            _currentFilter = 'cancelled';
            break;
        }
        _filterRides();
      });
    }
  }

  Future<void> _loadRides() async {
    setState(() {
      _isLoading = true;
      _lastDocument = null;
      _hasMore = true;
    });

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      if (driverData['driverId'] == null) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      Query query = FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverData['driverId'])
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      final snapshots = await query.get();

      if (snapshots.docs.isEmpty) {
        setState(() {
          _rides = [];
          _filteredRides = [];
          _isLoading = false;
          _hasMore = false;
        });
        return;
      }

      _lastDocument = snapshots.docs.last;

      setState(() {
        _rides = snapshots.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {...data, 'id': doc.id};
        }).toList();
        _filterRides();
        _isLoading = false;
        _hasMore = snapshots.docs.length >= _limit;
      });
    } catch (e) {
      debugPrint('Error loading rides: $e');
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الب��انات: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreRides() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      if (driverData['driverId'] == null || _lastDocument == null) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      Query query = FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverData['driverId'])
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      final snapshots = await query.get();

      if (snapshots.docs.isEmpty) {
        setState(() {
          _isLoadingMore = false;
          _hasMore = false;
        });
        return;
      }

      _lastDocument = snapshots.docs.last;

      final newRides = snapshots.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {...data, 'id': doc.id};
      }).toList();

      setState(() {
        _rides.addAll(newRides);
        _filterRides();
        _isLoadingMore = false;
        _hasMore = snapshots.docs.length >= _limit;
      });
    } catch (e) {
      debugPrint('Error loading more rides: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _filterRides() {
    List<Map<String, dynamic>> tempRides = List.from(_rides);

    if (_currentFilter == 'completed') {
      tempRides =
          tempRides.where((ride) => ride['status'] == 'completed').toList();
    } else if (_currentFilter == 'cancelled') {
      tempRides =
          tempRides.where((ride) => ride['status'] == 'cancelled').toList();
    }

    if (_selectedPeriod != 'الكل') {
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'اليوم':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'هذا الأسبوع':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'هذا الشهر':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2000);
      }

      tempRides = tempRides.where((ride) {
        final Timestamp? timestamp = ride['createdAt'] as Timestamp?;
        if (timestamp == null) return false;
        return timestamp.toDate().isAfter(startDate);
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempRides = tempRides.where((ride) {
        final String pickupAddress =
            ride['pickupAddress']?.toString().toLowerCase() ?? '';
        final String dropoffAddress =
            ride['dropoffAddress']?.toString().toLowerCase() ?? '';
        final String customerName =
            ride['customerName']?.toString().toLowerCase() ?? '';
        final String query = _searchQuery.toLowerCase();

        return pickupAddress.contains(query) ||
            dropoffAddress.contains(query) ||
            customerName.contains(query);
      }).toList();
    }

    setState(() {
      _filteredRides = tempRides;
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'مكتملة';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 'completed'
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'غير متوفر';
    if (date is Timestamp) {
      final DateTime dateTime = date.toDate();
      return DateFormat('yyyy/MM/dd - HH:mm').format(dateTime);
    }
    return 'غير متوفر';
  }

  String _formatDaysSince(dynamic date) {
    if (date == null) return '';
    if (date is Timestamp) {
      final DateTime dateTime = date.toDate();
      final difference = DateTime.now().difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return 'منذ ${difference.inMinutes} دقيقة';
        }
        return 'منذ ${difference.inHours} ساعة';
      } else if (difference.inDays < 30) {
        return 'منذ ${difference.inDays} يوم';
      } else {
        return _formatDate(date);
      }
    }
    return '';
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
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'سجل الرحلات',
                      style: AppTextStyles.arabicDisplaySmall.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Modern Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: AppColors.primary,
                        unselectedLabelColor: Colors.white,
                        labelStyle: AppTextStyles.arabicBody.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: AppTextStyles.arabicBody.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(text: 'الكل'),
                          Tab(text: 'المكتملة'),
                          Tab(text: 'الملغاة'),
                        ],
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
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : Column(
                          children: [
                            const SizedBox(height: 16),
                            _buildFilterBar(),
                            _buildSearchBar(),
                            Expanded(
                              child: _filteredRides.isEmpty
                                  ? _buildEmptyState()
                                  : _buildRidesList(),
                            ),
                            if (_isLoadingMore)
                              Container(
                                padding: const EdgeInsets.all(8),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'الفترة:',
              style: AppTextStyles.arabicTitle,
            ),
            const SizedBox(width: 8),
            ...['الكل', 'اليوم', 'هذا الأسبوع', 'هذا الشهر'].map((period) {
              final selected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(
                    period,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textOnPrimary
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: selected,
                  onSelected: (value) {
                    if (value) {
                      setState(() {
                        _selectedPeriod = period;
                        _filterRides();
                      });
                    }
                  },
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              );
            }).toList(),
          ],
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
          hintText: 'البحث عن رحلة... (عنوان، عميل...)',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _filterRides();
                    });
                  },
                )
              : null,
        ),
        textAlign: TextAlign.right,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _filterRides();
          });
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    IconData icon;
    String message;

    switch (_currentFilter) {
      case 'completed':
        icon = Icons.check_circle_outline;
        message = 'لا توجد رحلات مكتملة';
        break;
      case 'cancelled':
        icon = Icons.cancel_outlined;
        message = 'لا توجد رحلات ملغاة';
        break;
      default:
        icon = Icons.history_rounded;
        message = 'لا توجد رحلات سابقة';
    }

    if (_searchQuery.isNotEmpty) {
      message = 'لا توجد نتائج مطابقة للبحث';
      icon = Icons.search_off_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTextStyles.arabicBody.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (_rides.isNotEmpty && _filteredRides.isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedPeriod = 'الكل';
                  _filterRides();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إزالة الفلاتر'),
            ),
        ],
      ),
    );
  }

  Widget _buildRidesList() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadRides,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: _filteredRides.length,
        itemBuilder: (context, index) {
          final ride = _filteredRides[index];
          final status = ride['status'] as String? ?? 'completed';
          final fare = ride['fare'] is int
              ? (ride['fare'] as int).toDouble()
              : (ride['fare'] as num?)?.toDouble() ?? 0.0;
          final distance = ride['distance'] as num? ?? 0.0;
          final isCompleted = status == 'completed';

          final Timestamp? timestamp = isCompleted
              ? ride['completedAt'] as Timestamp?
              : ride['cancelledAt'] as Timestamp?;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppDecorations.cardDecoration,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(status),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppColors.textSecondary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _formatDaysSince(timestamp ?? ride['createdAt']),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLocationInfo(ride),
                  const Divider(height: 24, color: AppColors.divider),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            color: AppColors.success,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${fare.toStringAsFixed(0)} MRU',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      if (ride['customerName'] != null)
                        Text(
                          '${ride['customerName']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${ride['duration'] ?? '0'} دقيقة',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.route_rounded,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$distance كم',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationInfo(Map<String, dynamic> ride) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_rounded,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ride['pickupAddress'] ?? 'غير متوفر',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.0),
                          AppColors.primary.withOpacity(0.6),
                          AppColors.error.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textHint,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.0),
                          AppColors.primary.withOpacity(0.6),
                          AppColors.error.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(
                Icons.flag_rounded,
                color: AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ride['dropoffAddress'] ?? 'غير متوفر',
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
