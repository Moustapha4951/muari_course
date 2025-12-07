import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

// دالة لإنشاء أيقونة وأيقونة أمامية للتطبيق
Future<void> createAppIcons() async {
  // إنشاء أيقونات بأحجام مختلفة
  await _createIcon(48, 'mdpi');    // 48×48 للشاشات mdpi
  await _createIcon(72, 'hdpi');    // 72×72 للشاشات hdpi
  await _createIcon(96, 'xhdpi');   // 96×96 للشاشات xhdpi
  await _createIcon(144, 'xxhdpi'); // 144×144 للشاشات xxhdpi
  await _createIcon(192, 'xxxhdpi'); // 192×192 للشاشات xxxhdpi
  
  // إنشاء أيقونة أمامية (foreground) لكل حجم
  await _createForegroundIcon(108, 'mdpi');    // 108×108 للشاشات mdpi
  await _createForegroundIcon(162, 'hdpi');    // 162×162 للشاشات hdpi
  await _createForegroundIcon(216, 'xhdpi');   // 216×216 للشاشات xhdpi
  await _createForegroundIcon(324, 'xxhdpi');  // 324×324 للشاشات xxhdpi
  await _createForegroundIcon(432, 'xxxhdpi'); // 432×432 للشاشات xxxhdpi
}

// دالة إنشاء الأيقونة الرئيسية
Future<void> _createIcon(int size, String density) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // رسم خلفية دائرية
  final paint = Paint()
    ..color = const Color(0xFF2E3F51)
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
  
  // رسم حرف W
  final fontSize = size * 0.6;
  final textStyle = TextStyle(
    color: Colors.white,
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
  );
  
  final textSpan = TextSpan(
    text: 'W',
    style: textStyle,
  );
  
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    ),
  );
  
  // تحويل الرسم إلى صورة
  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // حفظ الأيقونة في مجلد مؤقت
  final directory = await getTemporaryDirectory();
  final iconPath = '${directory.path}/ic_launcher_$density.png';
  final iconFile = File(iconPath);
  await iconFile.writeAsBytes(pngBytes);
  
  print('تم إنشاء أيقونة بحجم $size×$size في: $iconPath');
}

// دالة إنشاء الأيقونة الأمامية (foreground)
Future<void> _createForegroundIcon(int size, String density) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  
  // الأيقونة الأمامية شفافة في الأطراف
  final paint = Paint()
    ..color = Colors.transparent;
  
  canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), paint);
  
  // رسم حرف W في المنتصف
  final fontSize = size * 0.5; // حجم أصغر للحرف
  final textStyle = TextStyle(
    color: Colors.white,
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
  );
  
  final textSpan = TextSpan(
    text: 'W',
    style: textStyle,
  );
  
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      (size - textPainter.width) / 2,
      (size - textPainter.height) / 2,
    ),
  );
  
  // تحويل الرسم إلى صورة
  final picture = recorder.endRecording();
  final img = await picture.toImage(size, size);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // حفظ الأيقونة الأمامية في مجلد مؤقت
  final directory = await getTemporaryDirectory();
  final iconPath = '${directory.path}/ic_launcher_foreground_$density.png';
  final iconFile = File(iconPath);
  await iconFile.writeAsBytes(pngBytes);
  
  print('تم إنشاء أيقونة أمامية بحجم $size×$size في: $iconPath');
} 