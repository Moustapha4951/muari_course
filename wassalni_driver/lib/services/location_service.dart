import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/sharedpreferences_helper.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static bool _isTracking = false;

  static Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    final driverData = await SharedPreferencesHelper.getDriverData();
    if (driverData == null || driverData['driverId'] == null) return;

    final driverId = driverData['driverId'];

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // تحديث كل 10 متر فقط
        timeLimit: Duration(seconds: 10), // الحد الأقصى للانتظار بين التحديثات
      ),
    ).listen((Position position) async {
      try {
        // تخزين آخر موقع صالح في الذاكرة المحلية لاستخدامه في حالة انقطاع الاتصال
        await SharedPreferencesHelper.setLastPosition(position);

        // تحديث الموقع في Firebase
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverId)
            .update({
          'location': GeoPoint(position.latitude, position.longitude),
          'lastLocationUpdate': FieldValue.serverTimestamp(),
          'accuracy': position.accuracy, // إضافة دقة الموقع
          'speed': position.speed, // إضافة سرعة السائق
        });
      } catch (e) {
        print('Error updating driver location: $e');
      }
    });

    _isTracking = true;
  }

  static void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }

  static Future<Position?> getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // إضافة دالة لاسترجاع آخر موقع معروف
  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('Error getting last known position: $e');
      return null;
    }
  }
}
