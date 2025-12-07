import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String name;
  final String phone;
  final String city;
  final bool isApproved;
  final bool isBanned;
  final String status;
  final double balance;
  final double rating;
  final GeoPoint? location;
  final DateTime? createdAt;
  final List<dynamic> completedRides;
  final List<dynamic> transactions;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.city,
    required this.isApproved,
    required this.isBanned,
    required this.status,
    required this.balance,
    required this.rating,
    this.location,
    this.createdAt,
    this.completedRides = const [],
    this.transactions = const [],
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // التعامل مع completedRides
    List<dynamic> completedRidesList = [];
    if (data['completedRides'] != null) {
      if (data['completedRides'] is List) {
        completedRidesList = List<dynamic>.from(data['completedRides']);
      } else if (data['completedRides'] is int) {
        // إذا كان العدد صفر أو أي رقم آخر، نترك القائمة فارغة
        completedRidesList = [];
      }
    }

    // التعامل مع transactions
    List<dynamic> transactionsList = [];
    if (data['transactions'] != null) {
      if (data['transactions'] is List) {
        transactionsList = List<dynamic>.from(data['transactions']);
      } else if (data['transactions'] is int) {
        // إذا كان العدد صفر أو أي رقم آخر، نترك القائمة فارغة
        transactionsList = [];
      }
    }

    return Driver(
      id: doc.id,
      name: data['name']?.toString() ?? 'بدون اسم',
      phone: data['phone']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      isApproved: data['isApproved'] == true,
      isBanned: data['isBanned'] == true,
      status: data['status']?.toString() ?? 'offline',
      balance: (data['balance'] is int)
          ? (data['balance'] as int).toDouble()
          : (data['balance'] as num?)?.toDouble() ?? 0.0,
      rating: (data['rating'] is int)
          ? (data['rating'] as int).toDouble()
          : (data['rating'] as num?)?.toDouble() ?? 0.0,
      location:
          data['location'] is GeoPoint ? data['location'] as GeoPoint : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : data['createdAt'] is String
                  ? DateTime.tryParse(data['createdAt'] as String)
                  : null)
          : null,
      completedRides: completedRidesList,
      transactions: transactionsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'city': city,
      'isApproved': isApproved,
      'isBanned': isBanned,
      'status': status,
      'balance': balance,
      'rating': rating,
      'location': location,
      'completedRides': completedRides,
      'transactions': transactions,
    };
  }
}
