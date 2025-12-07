import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

// دالة لتصغير الأيقونة وإنشاء نسخة جديدة مصغرة
Future<void> resizeAppIcon() async {
  try {
    // قراءة ملف الصورة الأصلي
    final ByteData data = await rootBundle.load('assets/app_icon.png');
    final List<int> bytes = data.buffer.asUint8List();
    final img.Image? originalImage = img.decodeImage(Uint8List.fromList(bytes));
    
    if (originalImage == null) {
      print('فشل في تحميل الصورة الأصلية');
      return;
    }
    
    // تصغير الصورة (تغيير الحجم إلى 192×192 بكسل)
    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: 192,
      height: 192,
    );
    
    // حفظ الصورة المصغرة في ملف جديد
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String resizedIconPath = '${appDir.path}/resized_app_icon.png';
    final File resizedIconFile = File(resizedIconPath);
    await resizedIconFile.writeAsBytes(img.encodePng(resizedImage));
    
    print('تم تصغير الأيقونة وحفظها في: $resizedIconPath');
    
    // يمكنك نسخ الملف المصغر إلى مجلد assets في المشروع
  } catch (e) {
    print('خطأ في تصغير الأيقونة: $e');
  }
} 