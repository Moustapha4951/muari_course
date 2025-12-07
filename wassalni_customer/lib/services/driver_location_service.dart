import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class DriverLocationService {
  static StreamSubscription<QuerySnapshot>? _driversSubscription;
  static Function(List<Map<String, dynamic>>)? _onDriversUpdate;
  static String? _currentCity;
  static Position? _currentPosition;
  static double _maxDistance = 1.0; // Default 1km

  /// Initialize the service with callback for driver updates
  static void initialize({
    required Function(List<Map<String, dynamic>>) onDriversUpdate,
    required String cityId,
    Position? currentPosition,
    double? maxDistanceKm,
  }) {
    _onDriversUpdate = onDriversUpdate;
    _currentCity = cityId;
    _currentPosition = currentPosition;
    if (maxDistanceKm != null) _maxDistance = maxDistanceKm;
    
    debugPrint('🔵 [DriverLocationService] Initialized for city: $cityId, maxDistance: $_maxDistance km');
  }

  /// Start listening for nearby available drivers
  static void startListening() {
    if (_currentCity == null) {
      debugPrint('🔴 [DriverLocationService] Cannot start listening - city not set');
      return;
    }

    debugPrint('🔵 [DriverLocationService] Starting to listen for drivers in $_currentCity');

    _driversSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .where('city', isEqualTo: _currentCity)
        .where('status', isEqualTo: 'online')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        debugPrint('🔵 [DriverLocationService] Received ${snapshot.docs.length} drivers');
        
        final List<Map<String, dynamic>> nearbyDrivers = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final driverLocation = data['location'] as GeoPoint?;
          
          if (driverLocation == null) {
            debugPrint('🟡 [DriverLocationService] Driver ${doc.id} has no location');
            continue;
          }

          // Calculate distance if customer position is available
          double? distance;
          if (_currentPosition != null) {
            distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              driverLocation.latitude,
              driverLocation.longitude,
            );

            // Filter by max distance
            if (distance > _maxDistance) {
              debugPrint('🟡 [DriverLocationService] Driver ${doc.id} is ${distance.toStringAsFixed(2)}km away (too far)');
              continue;
            }
          }

          nearbyDrivers.add({
            'id': doc.id,
            'name': data['name'] ?? 'سائق',
            'phone': data['phone'] ?? '',
            'location': driverLocation,
            'distance': distance,
            'rating': data['rating'] ?? 0.0,
            'completedRides': data['completedRides'] ?? 0,
          });

          debugPrint('✅ [DriverLocationService] Driver ${doc.id} added (${distance?.toStringAsFixed(2) ?? '?'} km away)');
        }

        debugPrint('🟢 [DriverLocationService] Total nearby drivers: ${nearbyDrivers.length}');
        
        // Notify listeners
        _onDriversUpdate?.call(nearbyDrivers);
      },
      onError: (error) {
        debugPrint('🔴 [DriverLocationService] Error: $error');
      },
    );
  }

  /// Update customer position and refresh nearby drivers
  static void updatePosition(Position position) {
    _currentPosition = position;
    debugPrint('🔵 [DriverLocationService] Position updated: ${position.latitude}, ${position.longitude}');
  }

  /// Update max distance filter
  static void updateMaxDistance(double distanceKm) {
    _maxDistance = distanceKm;
    debugPrint('🔵 [DriverLocationService] Max distance updated to: $_maxDistance km');
  }

  /// Calculate distance between two points in kilometers
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// Get nearby drivers for a specific location (used when creating ride request)
  static Future<List<String>> getNearbyDriverIds({
    required GeoPoint pickupLocation,
    required String cityId,
    double? maxDistanceKm,
  }) async {
    final maxDist = maxDistanceKm ?? _maxDistance;
    
    debugPrint('🔵 [DriverLocationService] ========== Getting nearby drivers ==========');
    debugPrint('🔵 [DriverLocationService] Pickup: ${pickupLocation.latitude}, ${pickupLocation.longitude}');
    debugPrint('🔵 [DriverLocationService] City ID: $cityId');
    debugPrint('🔵 [DriverLocationService] Max distance: $maxDist km');

    try {
      // First, check ALL drivers in the city (no filters)
      final allDriversSnapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('city', isEqualTo: cityId)
          .get();
      
      debugPrint('🔵 [DriverLocationService] Total drivers in city "$cityId" (no filters): ${allDriversSnapshot.docs.length}');
      
      // Log ALL drivers to see what's wrong
      if (allDriversSnapshot.docs.isNotEmpty) {
        debugPrint('📋 [DriverLocationService] ALL DRIVERS IN CITY:');
        for (var doc in allDriversSnapshot.docs) {
          final data = doc.data();
          debugPrint('   Driver ${doc.id}:');
          debugPrint('      - city: ${data['city']}');
          debugPrint('      - status: ${data['status']}');
          debugPrint('      - isApproved: ${data['isApproved']}');
          debugPrint('      - location: ${data['location']}');
          debugPrint('      - balance: ${data['balance']}');
        }
      }
      
      // Now check with filters
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('city', isEqualTo: cityId)
          .where('status', isEqualTo: 'online')
          .where('isApproved', isEqualTo: true)
          .get();

      debugPrint('🔵 [DriverLocationService] Drivers with status="online" AND isApproved=true: ${snapshot.docs.length}');

      final List<String> nearbyDriverIds = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final driverLocation = data['location'] as GeoPoint?;
        final driverCity = data['city'];
        final driverStatus = data['status'];
        final isApproved = data['isApproved'];
        
        debugPrint('🔍 [DriverLocationService] Driver ${doc.id}:');
        debugPrint('   - City: $driverCity');
        debugPrint('   - Status: $driverStatus');
        debugPrint('   - Approved: $isApproved');
        debugPrint('   - Location: ${driverLocation?.latitude}, ${driverLocation?.longitude}');
        
        if (driverLocation == null) {
          debugPrint('   ❌ No location data');
          continue;
        }

        final distance = _calculateDistance(
          pickupLocation.latitude,
          pickupLocation.longitude,
          driverLocation.latitude,
          driverLocation.longitude,
        );

        debugPrint('   - Distance: ${distance.toStringAsFixed(4)} km (${(distance * 1000).toStringAsFixed(0)} meters)');

        if (distance <= maxDist) {
          nearbyDriverIds.add(doc.id);
          debugPrint('   ✅ ADDED - Within range!');
        } else {
          debugPrint('   ❌ TOO FAR - Max: $maxDist km');
        }
      }

      debugPrint('🟢 [DriverLocationService] Found ${nearbyDriverIds.length} nearby drivers');
      debugPrint('🔵 [DriverLocationService] ========================================');
      return nearbyDriverIds;
    } catch (e) {
      debugPrint('🔴 [DriverLocationService] Error getting nearby drivers: $e');
      return [];
    }
  }

  /// Stop listening for driver updates
  static void stopListening() {
    _driversSubscription?.cancel();
    _driversSubscription = null;
    debugPrint('🔵 [DriverLocationService] Stopped listening');
  }

  /// Dispose the service
  static void dispose() {
    stopListening();
    _onDriversUpdate = null;
    _currentCity = null;
    _currentPosition = null;
    debugPrint('🔵 [DriverLocationService] Disposed');
  }
}
