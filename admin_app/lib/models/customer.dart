import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phone;
  final int ridesCount;
  final GeoPoint? homeLocation;
  final String? homeAddress;
  final GeoPoint? workLocation;
  final String? workAddress;
  final DateTime? lastRideDate;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.ridesCount = 0,
    this.homeLocation,
    this.homeAddress,
    this.workLocation,
    this.workAddress,
    this.lastRideDate,
    required this.createdAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      ridesCount: map['ridesCount'] ?? 0,
      homeLocation: map['homeLocation'] as GeoPoint?,
      homeAddress: map['homeAddress'],
      workLocation: map['workLocation'] as GeoPoint?,
      workAddress: map['workAddress'],
      lastRideDate: (map['lastRideDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'ridesCount': ridesCount,
      'homeLocation': homeLocation,
      'homeAddress': homeAddress,
      'workLocation': workLocation,
      'workAddress': workAddress,
      'lastRideDate': lastRideDate != null ? Timestamp.fromDate(lastRideDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    int? ridesCount,
    GeoPoint? homeLocation,
    String? homeAddress,
    GeoPoint? workLocation,
    String? workAddress,
    DateTime? lastRideDate,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      ridesCount: ridesCount ?? this.ridesCount,
      homeLocation: homeLocation ?? this.homeLocation,
      homeAddress: homeAddress ?? this.homeAddress,
      workLocation: workLocation ?? this.workLocation,
      workAddress: workAddress ?? this.workAddress,
      lastRideDate: lastRideDate ?? this.lastRideDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
