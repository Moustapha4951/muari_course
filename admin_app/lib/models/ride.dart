import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatus {
  pending,
  accepted,
  started,
  completed,
  cancelled,
}

class Ride {
  final String id;
  final String customerName;
  final String customerPhone;
  final String? driverName;
  final String? driverPhone;
  final GeoPoint pickupLocation;
  final String pickupAddress;
  final GeoPoint dropoffLocation;
  final String dropoffAddress;
  final bool isOpen;
  final double fare;
  final RideStatus status;
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final double distance;
  final String? driverId;
  final String customerId;
  final String? cityId;

  Ride({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.driverName,
    this.driverPhone,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.dropoffLocation,
    required this.dropoffAddress,
    required this.isOpen,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.startTime,
    this.endTime,
    required this.distance,
    this.driverId,
    required this.customerId,
    this.cityId,
  });

  factory Ride.fromMap(Map<String, dynamic> map, String id) {
    return Ride(
      id: id,
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      pickupLocation: map['pickupLocation'] as GeoPoint,
      pickupAddress: map['pickupAddress'] ?? '',
      dropoffLocation: map['dropoffLocation'] as GeoPoint,
      dropoffAddress: map['dropoffAddress'] ?? '',
      isOpen: map['isOpen'] ?? false,
      fare: (map['fare'] ?? 0).toDouble(),
      status: RideStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RideStatus.pending,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      startTime: (map['startTime'] as Timestamp?)?.toDate(),
      endTime: (map['endTime'] as Timestamp?)?.toDate(),
      distance: (map['distance'] ?? 0).toDouble(),
      driverId: map['driverId'],
      customerId: map['customerId'] ?? '',
      cityId: map['cityId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerName': customerName,
      'customerPhone': customerPhone,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupAddress,
      'dropoffLocation': dropoffLocation,
      'dropoffAddress': dropoffAddress,
      'isOpen': isOpen,
      'fare': fare,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'distance': distance,
      'driverId': driverId,
      'customerId': customerId,
      'cityId': cityId,
    };
  }

  Ride copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? driverName,
    String? driverPhone,
    GeoPoint? pickupLocation,
    String? pickupAddress,
    GeoPoint? dropoffLocation,
    String? dropoffAddress,
    bool? isOpen,
    double? fare,
    RideStatus? status,
    DateTime? createdAt,
    DateTime? startTime,
    DateTime? endTime,
    double? distance,
    String? driverId,
    String? customerId,
    String? cityId,
  }) {
    return Ride(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      isOpen: isOpen ?? this.isOpen,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distance: distance ?? this.distance,
      driverId: driverId ?? this.driverId,
      customerId: customerId ?? this.customerId,
      cityId: cityId ?? this.cityId,
    );
  }

  String get statusText {
    switch (status) {
      case RideStatus.pending:
        return 'في الانتظار';
      case RideStatus.accepted:
        return 'تم القبول';
      case RideStatus.started:
        return 'جارية';
      case RideStatus.completed:
        return 'مكتملة';
      case RideStatus.cancelled:
        return 'ملغية';
    }
  }

  Duration? get totalDuration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  bool get isActive => status == RideStatus.accepted || status == RideStatus.started;

  bool get isCompleted => status == RideStatus.completed;

  bool get isCancelled => status == RideStatus.cancelled;
}
