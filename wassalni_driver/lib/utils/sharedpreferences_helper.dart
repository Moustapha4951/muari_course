import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SharedPreferencesHelper {
  static const String keyDriverPhone = 'driver_phone';
  static const String keyDriverPassword = 'driver_password';
  static const String keyDriverId = 'driver_id';
  static const String keyDriverName = 'driver_name';
  static const String keyDriverCity = 'driver_city';

  // حفظ بيانات السائق
  static Future<void> saveDriverData({
    required String phone,
    required String password,
    required String driverId,
    String? name,
    String? city,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyDriverPhone, phone);
    await prefs.setString(keyDriverPassword, password);
    await prefs.setString(keyDriverId, driverId);
    if (name != null) await prefs.setString(keyDriverName, name);
    if (city != null) await prefs.setString(keyDriverCity, city);
  }

  // جلب بيانات السائق
  static Future<Map<String, String?>> getDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'phone': prefs.getString(keyDriverPhone),
      'password': prefs.getString(keyDriverPassword),
      'driverId': prefs.getString(keyDriverId),
      'name': prefs.getString(keyDriverName),
      'city': prefs.getString(keyDriverCity),
    };
  }

  // حذف بيانات السائق (تسجيل الخروج)
  static Future<void> clearDriverData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyDriverPhone);
    await prefs.remove(keyDriverPassword);
    await prefs.remove(keyDriverId);
    await prefs.remove(keyDriverName);
    await prefs.remove(keyDriverCity);
  }

  // التحقق من وجود بيانات تسجيل الدخول
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverPhone) != null &&
        prefs.getString(keyDriverPassword) != null &&
        prefs.getString(keyDriverId) != null;
  }

  static saveActiveRide(
      {required String rideId,
      required bool isOpenRide,
      required String status}) {}

  static updateActiveRideStatus(String s) {}

  static removePendingRideId() {}

  static removeActiveRide() {}

  // إضافة دالة الحصول على معرّف المستخدم
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverId);
  }

  // إضافة دالة الحصول على اسم السائق
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverName);
  }

  // إضافة دالة الحصول على رقم هاتف السائق
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverPhone);
  }

  // إضافة دالة الحصول على مدينة السائق
  static Future<String?> getUserCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyDriverCity);
  }

  // إضافة الدالة المفقودة لتخزين معرف الرحلة المعلقة
  static Future<bool> setPendingRideId(String rideId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_ride_id', rideId);
    debugPrint(
        'SharedPreferencesHelper: تم تخزين معرف الرحلة المعلقة: $rideId');
    return true;
  }

  // إضافة دالة للحصول على معرف الرحلة المعلقة
  static Future<String?> getPendingRideId() async {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString('pending_ride_id');
    debugPrint('SharedPreferencesHelper: معرف الرحلة المعلقة المخزن: $rideId');
    return rideId;
  }

  // إضافة دالة لحذف معرف الرحلة المعلقة بعد معالجتها
  static Future<bool> clearPendingRideId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_ride_id');
    debugPrint('SharedPreferencesHelper: تم مسح معرف الرحلة المعلقة');
    return true;
  }

  // إضافة طريقة لقراءة معرف الرحلة المحفوظ في التخزين المشترك من Native
  static Future<String?> getPendingRideIdFromNative() async {
    try {
      const platform =
          MethodChannel('com.example.wassalni_driver/app_launcher');
      final rideId = await platform.invokeMethod<String>('getPendingRideId');
      debugPrint('تم استرجاع معرف الرحلة من التخزين المشترك: $rideId');
      return rideId;
    } catch (e) {
      debugPrint('خطأ في استرجاع معرف الرحلة من التخزين المشترك: $e');
      return null;
    }
  }

  // إضافة دالة لحفظ نوع الرحلة (مفتوحة أم عادية)
  static Future<bool> setPendingRideType(bool isOpenRide) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pending_ride_is_open', isOpenRide);
    debugPrint(
        'SharedPreferencesHelper: تم تخزين نوع الرحلة المعلقة: ${isOpenRide ? "مفتوحة" : "عادية"}');
    return true;
  }

  // إضافة دالة للحصول على نوع الرحلة
  static Future<bool?> getPendingRideType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('pending_ride_is_open');
  }

  // دالة لحذف مفتاح محدد من SharedPreferences
  static Future<bool> clearData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      debugPrint('SharedPreferencesHelper: تم حذف البيانات المخزنة: $key');
      return true;
    } catch (e) {
      debugPrint('SharedPreferencesHelper: خطأ في حذف البيانات: $e');
      return false;
    }
  }

  // إضافة دالة لحفظ آخر موقع للسائق
  static Future<bool> setLastPosition(position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_position_lat', position.latitude);
      await prefs.setDouble('last_position_lng', position.longitude);
      await prefs.setInt(
          'last_position_time', DateTime.now().millisecondsSinceEpoch);
      debugPrint(
          'SharedPreferencesHelper: تم حفظ آخر موقع للسائق: Lat=${position.latitude}, Lng=${position.longitude}');
      return true;
    } catch (e) {
      debugPrint('SharedPreferencesHelper: خطأ في حفظ موقع السائق: $e');
      return false;
    }
  }

  // إضافة دالة لجلب آخر موقع مخزن للسائق
  static Future<Map<String, dynamic>?> getLastPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_position_lat');
      final lng = prefs.getDouble('last_position_lng');
      final time = prefs.getInt('last_position_time');

      if (lat == null || lng == null || time == null) {
        return null;
      }

      return {
        'latitude': lat,
        'longitude': lng,
        'timestamp': time,
      };
    } catch (e) {
      debugPrint('SharedPreferencesHelper: خطأ في جلب آخر موقع للسائق: $e');
      return null;
    }
  }
}
