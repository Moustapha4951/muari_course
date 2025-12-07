import 'package:cloud_firestore/cloud_firestore.dart';

class City {
  final String id;
  final String name;
  final int driversCount;
  final int customersCount;
  final GeoPoint location;
  final DateTime createdAt;
  final bool isActive;

  City({
    required this.id,
    required this.name,
    required this.driversCount,
    required this.customersCount,
    required this.location,
    required this.createdAt,
    this.isActive = true,
  });

  factory City.fromMap(Map<String, dynamic> map, String id) {
    return City(
      id: id,
      name: map['name'] ?? '',
      driversCount: map['driversCount'] ?? 0,
      customersCount: map['customersCount'] ?? 0,
      location: map['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'driversCount': driversCount,
      'customersCount': customersCount,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  City copyWith({
    String? id,
    String? name,
    int? driversCount,
    int? customersCount,
    GeoPoint? location,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return City(
      id: id ?? this.id,
      name: name ?? this.name,
      driversCount: driversCount ?? this.driversCount,
      customersCount: customersCount ?? this.customersCount,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  int get totalUsers => driversCount + customersCount;
}