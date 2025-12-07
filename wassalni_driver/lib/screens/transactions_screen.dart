import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rimapp_driver/utils/app_theme.dart';
import '../utils/sharedpreferences_helper.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  double _totalBalance = 0;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final driverData = await SharedPreferencesHelper.getDriverData();
      final driverId = driverData['driverId'];
      if (driverId == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'لم يتم العثور على معلومات السائق';
        });
        return;
      }
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      if (driverDoc.exists) {
        final data = driverDoc.data();
        _totalBalance = (data?['balance'] ?? 0).toDouble();
      }
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .where('driverId', isEqualTo: driverId)
          .orderBy('createdAt', descending: true)
          .get();
      final List<Map<String, dynamic>> transactions = [];
      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] is Timestamp
            ? data['createdAt'] as Timestamp
            : Timestamp.now();
        transactions.add({
          ...data,
          'id': doc.id,
          'date': createdAt,
          'description': data['reason'] ?? 'معاملة',
          'type': _getTransactionType(data['type'] ?? ''),
        });
      }
      setState(() {
        _transactions = transactions;
        _filteredTransactions = transactions;
        _isLoading = false;
        _hasError = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'حدث خطأ أثناء تحميل المعاملات: $error';
      });
    }
  }

  void _searchTransactions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTransactions = _transactions;
      } else {
        _filteredTransactions = _transactions.where((transaction) {
          final description =
              transaction['description']?.toString().toLowerCase() ?? '';
          final amount = transaction['amount']?.toString() ?? '';
          return description.contains(query.toLowerCase()) ||
              amount.contains(query);
        }).toList();
      }
    });
  }

  String _getTransactionType(String originalType) {
    if (originalType.contains('deduction') ||
        originalType.contains('fee') ||
        originalType.contains('debt')) {
      return 'debit';
    } else if (originalType.contains('payment') ||
        originalType.contains('deposit') ||
        originalType.contains('credit')) {
      return 'credit';
    }
    return 'other';
  }

  Color _getAmountColor(String type) {
    switch (type) {
      case 'credit':
        return AppColors.success;
      case 'debit':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'credit':
        return Icons.trending_up_rounded;
      case 'debit':
        return Icons.trending_down_rounded;
      default:
        return Icons.swap_horiz_rounded;
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
                            Icons.receipt_long_rounded,
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
                            onPressed: _loadTransactions,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'المعاملات المالية',
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _hasError
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                _errorMessage,
                                style: AppTextStyles.arabicBody.copyWith(
                                  color: AppColors.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),
                                _buildBalanceHeader(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'بحث في المعاملات...',
                                      prefixIcon: const Icon(Icons.search_rounded),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: _searchTransactions,
                                  ),
                                ),
                                Expanded(child: _buildTransactionsList()),
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

  Widget _buildBalanceHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الرصيد الحالي',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('متاح للسحب',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_totalBalance.toStringAsFixed(0),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text('MRU',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_rounded,
                size: 80, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text('لا توجد معاملات',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('لم يتم العثور على أي معاملات مالية بعد',
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTransactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        final type = transaction['type'] as String;
        final amount = (transaction['amount'] as num).toDouble();
        final date = transaction['date'] as Timestamp;
        final description = transaction['description'] as String;
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getAmountColor(type).withOpacity(0.15),
              child:
                  Icon(_getTransactionIcon(type), color: _getAmountColor(type)),
            ),
            title: Text(description,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatDate(date)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    '${type == 'credit' ? '+' : '-'} ${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: _getAmountColor(type),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('MRU',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(Timestamp date) {
    final DateTime dateTime = date.toDate();
    return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
  }
}
