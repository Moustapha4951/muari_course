import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

Future<void> createAndSaveAppIcons() async {
  // إنشاء مجموعة أيقونات بأحجام مختلفة
  await _createAndSaveIcon(48, 'mipmap-mdpi');
  await _createAndSaveIcon(72, 'mipmap-hdpi');
  await _createAndSaveIcon(96, 'mipmap-xhdpi');
  await _createAndSaveIcon(144, 'mipmap-xxhdpi');
  await _createAndSaveIcon(192, 'mipmap-xxxhdpi');
}

Future<void> _createAndSaveIcon(int size, String folder) async {
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
  
  // حفظ الصورة في المجلد المؤقت
  final directory = await getTemporaryDirectory();
  final iconPath = '${directory.path}/ic_launcher_$folder.png';
  final iconFile = File(iconPath);
  await iconFile.writeAsBytes(pngBytes);
  
  print('تم إنشاء أيقونة $folder بحجم $size×$size في: $iconPath');
} 