import 'package:cloud_firestore/cloud_firestore.dart';

class Price {
  final String id;
  final double minimumFare;
  final double pricePerKm;
  final double maximumKm;
  final double openRideBaseFare;
  final double openRidePerMinute;
  final double nightFareMultiplier;
  final double driverShare;
  final double appCommission;
  final double? cancellationFee;
  final DateTime lastUpdated;
  final bool isActive;

  Price({
    required this.id,
    required this.minimumFare,
    required this.pricePerKm,
    required this.maximumKm,
    required this.openRideBaseFare,
    required this.openRidePerMinute,
    required this.nightFareMultiplier,
    required this.driverShare,
    required this.appCommission,
    this.cancellationFee,
    required this.lastUpdated,
    this.isActive = true,
  });

  factory Price.fromMap(Map<String, dynamic> map, String id) {
    return Price(
      id: id,
      minimumFare: (map['minimumFare'] ?? 0).toDouble(),
      pricePerKm: (map['pricePerKm'] ?? 0).toDouble(),
      maximumKm: (map['minimumKm'] ?? 0).toDouble(),
      openRideBaseFare: (map['openRideBaseFare'] ?? 0).toDouble(),
      openRidePerMinute: (map['openRidePerMinute'] ?? 0).toDouble(),
      nightFareMultiplier: (map['nightFareMultiplier'] ?? 1).toDouble(),
      driverShare: (map['driverShare'] ?? 0.8).toDouble(),
      appCommission: (map['appCommission'] ?? 0.2).toDouble(),
      cancellationFee: map['cancellationFee']?.toDouble(),
      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'minimumFare': minimumFare,
      'pricePerKm': pricePerKm,
      'minimumKm': maximumKm,
      'openRideBaseFare': openRideBaseFare,
      'openRidePerMinute': openRidePerMinute,
      'nightFareMultiplier': nightFareMultiplier,
      'driverShare': driverShare,
      'appCommission': appCommission,
      if (cancellationFee != null) 'cancellationFee': cancellationFee,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isActive': isActive,
    };
  }

  Price copyWith({
    String? id,
    double? minimumFare,
    double? pricePerKm,
    double? maximumKm,
    double? openRideBaseFare,
    double? openRidePerMinute,
    double? nightFareMultiplier,
    double? driverShare,
    double? appCommission,
    double? cancellationFee,
    DateTime? lastUpdated,
    bool? isActive,
  }) {
    return Price(
      id: id ?? this.id,
      minimumFare: minimumFare ?? this.minimumFare,
      pricePerKm: pricePerKm ?? this.pricePerKm,
      maximumKm: maximumKm ?? this.maximumKm,
      openRideBaseFare: openRideBaseFare ?? this.openRideBaseFare,
      openRidePerMinute: openRidePerMinute ?? this.openRidePerMinute,
      nightFareMultiplier: nightFareMultiplier ?? this.nightFareMultiplier,
      driverShare: driverShare ?? this.driverShare,
      appCommission: appCommission ?? this.appCommission,
      cancellationFee: cancellationFee ?? this.cancellationFee,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isActive: isActive ?? this.isActive,
    );
  }

  double calculateRegularRideFare(double distance, bool isNightTime) {
    double baseFare;

    if (distance <= maximumKm) {
      baseFare = minimumFare;
    } else {
      baseFare = minimumFare + ((distance - maximumKm) * pricePerKm);
    }

    if (isNightTime) {
      baseFare *= nightFareMultiplier;
    }

    return baseFare;
  }

  double calculateOpenRideFare(int minutes, bool isNightTime) {
    double baseFare = openRideBaseFare + (minutes * openRidePerMinute);

    if (isNightTime) {
      baseFare *= nightFareMultiplier;
    }

    return baseFare;
  }

  double calculateDriverShare(double totalFare) {
    return totalFare * driverShare;
  }

  double calculateAppShare(double totalFare) {
    return totalFare * appCommission;
  }

  bool get isValid {
    return (driverShare + appCommission) == 1.0;
  }
}
