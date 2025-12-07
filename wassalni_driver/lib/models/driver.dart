import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String? id;
  final String name;
  final String phone;
  final String password;
  final String status;
  final String city;
  final bool isApproved;
  final double balance;
  final List<String> completedRides;
  final List<Map<String, dynamic>> transactions;
  final GeoPoint location;
  final DateTime? createdAt;

  Driver({
    this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.city,
    this.isApproved = false,
    this.status = 'offline',
    this.balance = 0,
    this.completedRides = const [],
    this.transactions = const [],
    this.location = const GeoPoint(0, 0),
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'city': city,
      'isApproved': isApproved,
      'status': status,
      'balance': balance,
      'completedRides': completedRides,
      'transactions': transactions,
      'location': location,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map, String id) {
    dynamic completedRidesData = map['completedRides'] ?? [];
    List<String> completedRidesList = [];

    if (completedRidesData is List) {
      completedRidesList =
          List<String>.from(completedRidesData.map((item) => item.toString()));
    }

    return Driver(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      city: map['city'] ?? '',
      isApproved: map['isApproved'] ?? false,
      status: map['status'] ?? 'offline',
      balance: (map['balance'] ?? 0).toDouble(),
      completedRides: completedRidesList,
      transactions: List<Map<String, dynamic>>.from(map['transactions'] ?? []),
      location: map['location'] ?? const GeoPoint(0, 0),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
