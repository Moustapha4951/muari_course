import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharedPreferencesHelper {
  static const String keyAdminPhone = 'admin_phone';
  static const String keyAdminPassword = 'admin_password';
  static const String keyAdminId = 'admin_id';

  static Future<bool> saveAdminData({
    required String phone,
    required String password,
    required String adminId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAdminPhone, phone);
      await prefs.setString(keyAdminPassword, password);
      await prefs.setString(keyAdminId, adminId);
      return true;
    } catch (e) {
      print('حدث خطأ أثناء حفظ بيانات المشرف: $e');
      return false;
    }
  }

  static Future<Map<String, String?>> getAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'phone': prefs.getString(keyAdminPhone),
        'password': prefs.getString(keyAdminPassword),
        'adminId': prefs.getString(keyAdminId),
      };
    } catch (e) {
      print('حدث خطأ أثناء جلب بيانات المشرف: $e');
      return {
        'phone': null,
        'password': null,
        'adminId': null,
      };
    }
  }

  static Future<bool> clearAdminData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAdminPhone);
      await prefs.remove(keyAdminPassword);
      await prefs.remove(keyAdminId);
      return true;
    } catch (e) {
      print('حدث خطأ أثناء حذف بيانات المشرف: $e');
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString(keyAdminId);
      final phone = prefs.getString(keyAdminPhone);
      final password = prefs.getString(keyAdminPassword);

      if (adminId != null && phone != null && password != null) {
        // Verify admin still exists and is approved
        try {
          final adminDoc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(adminId)
              .get();

          if (adminDoc.exists) {
            final adminData = adminDoc.data() as Map<String, dynamic>;
            return adminData['isApproved'] == true;
          }
        } catch (e) {
          print('Error verifying admin status: $e');
        }
      }
      return false;
    } catch (e) {
      print('حدث خطأ أثناء التحقق من تسجيل الدخول: $e');
      return false;
    }
  }
}
