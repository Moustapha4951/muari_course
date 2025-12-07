import 'package:cloud_firestore/cloud_firestore.dart';

class Admin {
  final String? id;
  final String name;
  final String phone;
  final String password;
  final String role;
  final bool isApproved;
  final DateTime? createdAt;

  Admin({
    this.id,
    required this.name,
    required this.phone,
    required this.password,
    this.role = 'supervisor',
    this.isApproved = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      'isApproved': isApproved,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory Admin.fromMap(Map<String, dynamic> map, String id) {
    return Admin(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      password: map['password'] ?? '',
      role: map['role'] ?? 'supervisor',
      isApproved: map['isApproved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}