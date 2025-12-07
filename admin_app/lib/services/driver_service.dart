import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver.dart';

class DriverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // جلب جميع السائقين
  Future<List<Driver>> getAllDrivers() async {
    final snapshot = await _firestore.collection('drivers').get();
    return snapshot.docs.map((doc) => Driver.fromFirestore(doc)).toList();
  }

  // إضافة رصيد للسائق
  Future<void> addBalance(
    String driverId,
    String driverName,
    double amount,
    String reason,
  ) async {
    final driverRef = _firestore.collection('drivers').doc(driverId);
    final statsRef = _firestore.collection('app_statistics').doc('drivers');

    return _firestore.runTransaction((transaction) async {
      final driverDoc = await transaction.get(driverRef);

      if (!driverDoc.exists) {
        throw Exception('لم يتم العثور على بيانات السائق');
      }

      // جلب الإحصائيات الحالية
      final statsDoc = await transaction.get(statsRef);
      final currentTotalBalance = statsDoc.exists
          ? (statsDoc.data()?['totalBalance'] ?? 1180000).toDouble()
          : 1180000.0;

      final currentBalance =
          (driverDoc.data()?['balance'] as num?)?.toDouble() ?? 0.0;
      final newBalance = currentBalance + amount;

      // تحديث رصيد السائق
      transaction.update(driverRef, {'balance': newBalance});

      // تحديث إجمالي الرصيد
      if (statsDoc.exists) {
        transaction.update(statsRef, {
          'totalBalance': currentTotalBalance + amount,
        });
      } else {
        transaction.set(statsRef, {
          'totalBalance': 1180000.0 + amount,
        });
      }

      // إضافة المعاملة
      final transactionRef = _firestore.collection('transactions').doc();
      transaction.set(transactionRef, {
        'driverId': driverId,
        'driverName': driverName,
        'amount': amount,
        'type': 'deposit',
        'reason': reason,
        'date': FieldValue.serverTimestamp(),
        'balance': newBalance,
        'adminNote': 'تم الشحن من لوحة التحكم',
      });
    });
  }

  // قبول السائق
  Future<void> approveDriver(String driverId) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'isApproved': true,
      'status': 'offline',
    });
  }

  // إنشاء سائق اختباري
  Future<void> createTestDriver() async {
    final driverId = DateTime.now().millisecondsSinceEpoch.toString();

    await _firestore.collection('drivers').doc(driverId).set({
      'name': 'سائق اختباري ${driverId.substring(driverId.length - 4)}',
      'phone': '0000${driverId.substring(driverId.length - 6)}',
      'password': '123456',
      'city': 'نواكشوط',
      'isApproved': false, // Changed to false for testing
      'isBanned': false,
      'status': 'offline',
      'balance': 0,
      'rating': 0.0,
      'completedRides': [],
      'transactions': [],
      'location': const GeoPoint(0, 0),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // حظر/إلغاء حظر السائق
  Future<void> toggleDriverBan(String driverId, bool isBanned) async {
    await _firestore.collection('drivers').doc(driverId).update({
      'isBanned': isBanned,
      'status': 'offline',
    });
  }
}
