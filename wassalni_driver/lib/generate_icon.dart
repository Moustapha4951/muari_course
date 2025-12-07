import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

Future<void> generateOptimizedIcon() async {
  // إنشاء أيقونة برمجياً بحجم مثالي
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(512, 512);
  
  // رسم خلفية دائرية
  final paint = Paint()
    ..color = const Color(0xFF2E3F51)
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
  
  // رسم حرف W باللون الأبيض
  const textStyle = TextStyle(
    color: Colors.white,
    fontSize: 250,
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
  
  textPainter.layout(minWidth: 0, maxWidth: size.width);
  textPainter.paint(
    canvas,
    Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    ),
  );
  
  // تحويل الرسم إلى صورة
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // حفظ الصورة في ملف مؤقت
  final directory = await getTemporaryDirectory();
  final iconPath = '${directory.path}/wassalni_icon.png';
  final iconFile = File(iconPath);
  await iconFile.writeAsBytes(pngBytes);
  
  print('تم إنشاء أيقونة مثالية في: $iconPath');
  print('يرجى نسخ هذا الملف إلى مجلد assets في المشروع');
} 