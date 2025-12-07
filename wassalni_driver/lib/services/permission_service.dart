import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// خدمة للتعامل مع أذونات النظام المختلفة
class PermissionService {
  static const MethodChannel _channel =
      MethodChannel('com.example.wassalni_driver/system_overlay');

  /// طلب جميع الأذونات المطلوبة للتطبيق
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // طلب أذونات الموقع
    final locationStatus = await requestLocationPermission();
    if (!locationStatus) {
      _showPermissionDialog(context, 'إذن الموقع',
          'يحتاج التطبيق إلى إذن الموقع للعثور على الرحلات القريبة منك. يرجى منحه في إعدادات التطبيق.');
      return false;
    }

    // طلب أذونات الإشعارات
    final notificationStatus = await requestNotificationPermission();
    if (!notificationStatus) {
      _showPermissionDialog(context, 'إذن الإشعارات',
          'يحتاج التطبيق إلى إذن الإشعارات لتنبيهك بالرحلات الجديدة. يرجى منحه في إعدادات التطبيق.');
      return false;
    }

    // طلب إذن العرض فوق التطبيقات الأخرى
    final overlayStatus = await requestOverlayPermission();
    if (!overlayStatus) {
      _showPermissionDialog(context, 'إذن العرض فوق التطبيقات',
          'يحتاج التطبيق إلى إذن العرض فوق التطبيقات الأخرى للعمل في الخلفية وعرض الرحلات الجديدة. يرجى منحه في إعدادات التطبيق.');
      return false;
    }

    // طلب إذن تجاهل تحسينات البطارية
    final batteryStatus = await requestBatteryOptimizationPermission();
    if (!batteryStatus) {
      _showPermissionDialog(context, 'تجاهل تحسينات البطارية',
          'يحتاج التطبيق إلى إذن تجاهل تحسينات البطارية للعمل في الخلفية. يرجى منحه في إعدادات التطبيق.');
      return false;
    }

    return true;
  }

  /// طلب إذن الموقع
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  /// طلب إذن الإشعارات
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// طلب إذن العرض فوق التطبيقات الأخرى
  static Future<bool> requestOverlayPermission() async {
    try {
      // أولاً، تحقق مما إذا كان الإذن ممنوحًا بالفعل
      final hasPermission =
          await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (hasPermission) {
        return true;
      }

      // طلب الإذن
      await _channel.invokeMethod('requestOverlayPermission');

      // انتظر قليلاً ثم تحقق مرة أخرى
      await Future.delayed(const Duration(seconds: 3));
      final granted =
          await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      return granted;
    } catch (e) {
      debugPrint('خطأ في طلب إذن العرض فوق التطبيقات الأخرى: $e');
      return false;
    }
  }

  /// طلب إذن تجاهل تحسينات البطارية
  static Future<bool> requestBatteryOptimizationPermission() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('خطأ في طلب إذن تجاهل تحسينات البطارية: $e');
      return false;
    }
  }

  /// عرض حوار طلب إذن
  static void _showPermissionDialog(
      BuildContext context, String permissionName, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إذن $permissionName مطلوب'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }
}
