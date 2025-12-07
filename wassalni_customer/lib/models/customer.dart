import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;
  final int completedRides;
  final double rating;
  final bool isBanned;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.createdAt,
    this.completedRides = 0,
    this.rating = 0.0,
    this.isBanned = false,
  });

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      completedRides: map['completedRides'] ?? 0,
      rating: (map['rating'] ?? 0.0).toDouble(),
      isBanned: map['isBanned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedRides': completedRides,
      'rating': rating,
      'isBanned': isBanned,
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? createdAt,
    int? completedRides,
    double? rating,
    bool? isBanned,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
      completedRides: completedRides ?? this.completedRides,
      rating: rating ?? this.rating,
      isBanned: isBanned ?? this.isBanned,
    );
  }
}
