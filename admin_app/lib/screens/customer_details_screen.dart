import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' as intl;

class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;
  final String collectionName;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    required this.customerData,
    this.collectionName = 'customers',
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  bool _isLoading = false;
  final _banReasonController = TextEditingController();
  final _banDurationController = TextEditingController();
  List<QueryDocumentSnapshot> _rides = [];
  late Map<String, dynamic> _customerData;

  @override
  void initState() {
    super.initState();
    _customerData = Map<String, dynamic>.from(widget.customerData);
    _loadCustomerData();
    _loadRides();
  }

  Future<void> _loadCustomerData() async {
    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.customerId)
          .get();

      if (customerDoc.exists) {
        setState(() {
          _customerData = customerDoc.data() ?? {};
        });
      }
    } catch (e) {
      debugPrint('Error loading customer data: $e');
    }
  }

  Future<void> _loadRides() async {
    setState(() => _isLoading = true);
    try {
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('customerId', isEqualTo: widget.customerId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _rides = ridesSnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading rides: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _banCustomer() async {
    if (_banDurationController.text.isEmpty ||
        _banReasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال جميع البيانات المطلوبة')),
      );
      return;
    }

    final days = int.tryParse(_banDurationController.text);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال عدد أيام صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final banEndDate = DateTime.now().add(Duration(days: days));
      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.customerId)
          .update({
        'isBanned': true,
        'banReason': _banReasonController.text,
        'banEndDate': Timestamp.fromDate(banEndDate),
      });

      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حظر الزبون بنجاح')),
      );

      setState(() {
        _customerData['isBanned'] = true;
        _customerData['banReason'] = _banReasonController.text;
        _customerData['banEndDate'] = Timestamp.fromDate(banEndDate);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ ما، الرجاء المحاولة مرة أخرى')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _unbanCustomer() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.customerId)
          .update({
        'isBanned': false,
        'banReason': null,
        'banEndDate': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء حظر الزبون بنجاح')),
      );
      setState(() {
        _customerData['isBanned'] = false;
        _customerData['banReason'] = null;
        _customerData['banEndDate'] = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ ما، الرجاء المحاولة مرة أخرى')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteCustomer() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الزبون', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من حذف هذا الزبون؟ لا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .doc(widget.customerId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الزبون بنجاح')),
        );
        Navigator.pop(context); // Return to customers list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ ما، الرجاء المحاولة مرة أخرى')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showBanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حظر الزبون', textAlign: TextAlign.right),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _banDurationController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'مدة الحظر (بالأيام)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _banReasonController,
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سبب الحظر',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: _banCustomer,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حظر'),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final createdAt = ride['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? intl.DateFormat('yyyy/MM/dd HH:mm').format(createdAt.toDate())
        : 'غير متوفر';

    final status = ride['status'] ?? 'unknown';
    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'مكتملة';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ملغية';
        break;
      case 'ongoing':
        statusColor = Colors.blue;
        statusText = 'جارية';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير معروفة';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride['pickupAddress'] ?? 'غير محدد',
                    style: const TextStyle(fontSize: 14),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ride['dropoffAddress'] ?? 'غير محدد',
                    style: const TextStyle(fontSize: 14),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المسافة: ${ride['distance']?.toStringAsFixed(1) ?? '0'} كم',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                Text(
                  'السعر: ${ride['fare'] ?? '0'} MRU',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBanned = _customerData['isBanned'] ?? false;
    final completedRides = _customerData['completedRides'] ?? 0;
    final totalSpent = _customerData['totalSpent'] ?? 0;
    final rating = _customerData['rating'] ?? 0.0;
    final createdAt = _customerData['createdAt'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الزبون'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E3F51),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRides,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _customerData['name'] ?? 'غير معروف',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isBanned)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'محظور',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('رقم الهاتف: ${_customerData['phone']}'),
                            if (createdAt != null)
                              Text(
                                'تاريخ التسجيل: ${intl.DateFormat('yyyy/MM/dd').format(createdAt.toDate())}',
                              ),
                            if (isBanned && _customerData['banEndDate'] != null)
                              Text(
                                'تاريخ انتهاء الحظر: ${intl.DateFormat('yyyy/MM/dd').format((_customerData['banEndDate'] as Timestamp).toDate())}',
                                style: const TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('عدد الرحلات: $completedRides'),
                                Text(
                                  'التقييم: ${rating.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              'إجمالي المصروفات: $totalSpent MRU',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E3F51),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_rides.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'آخر الرحلات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'العدد: ${_rides.length}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._rides.map((doc) =>
                          _buildRideCard(doc.data() as Map<String, dynamic>)),
                    ],
                    const SizedBox(height: 16),
                    if (!isBanned)
                      ElevatedButton(
                        onPressed: _showBanDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('حظر الزبون'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _unbanCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('إلغاء حظر الزبون'),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _deleteCustomer,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('حذف الزبون'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _banReasonController.dispose();
    _banDurationController.dispose();
    super.dispose();
  }
}
