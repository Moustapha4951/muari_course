import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_theme.dart';

/// Custom Map Markers Generator
class CustomMarkers {
  /// Create a custom driver marker
  static Future<BitmapDescriptor> createDriverMarker({
    bool isOnline = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 140.0;
    const center = Offset(size / 2, size / 2);

    // Draw outer glow
    final glowPaint = Paint()
      ..color = (isOnline ? AppColors.success : AppColors.textHint)
          .withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 50, glowPaint);

    // Draw white background
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 45, bgPaint);

    // Draw gradient circle
    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(20, 20),
        const Offset(120, 120),
        isOnline
            ? [AppColors.primary, AppColors.primaryLight]
            : [AppColors.textHint, AppColors.textSecondary],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 42, gradientPaint);

    // Draw car icon
    _drawCarIcon(canvas, center, Colors.white);

    // Draw online status indicator
    if (isOnline) {
      final statusPaint = Paint()
        ..color = AppColors.success
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(center.dx + 25, center.dy - 25),
        8,
        statusPaint,
      );
      
      // Status border
      final statusBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(
        Offset(center.dx + 25, center.dy - 25),
        8,
        statusBorderPaint,
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Create a custom pickup marker
  static Future<BitmapDescriptor> createPickupMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 120.0;
    const center = Offset(size / 2, size / 2);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(center.dx, center.dy + 5), 35, shadowPaint);

    // Draw pin shape
    final pinPath = Path();
    pinPath.moveTo(center.dx, center.dy + 35);
    pinPath.quadraticBezierTo(
      center.dx - 30,
      center.dy + 10,
      center.dx - 30,
      center.dy - 15,
    );
    pinPath.arcToPoint(
      Offset(center.dx + 30, center.dy - 15),
      radius: const Radius.circular(30),
    );
    pinPath.quadraticBezierTo(
      center.dx + 30,
      center.dy + 10,
      center.dx,
      center.dy + 35,
    );

    // Draw pin with gradient
    final pinPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - 30, center.dy - 30),
        Offset(center.dx + 30, center.dy + 30),
        [AppColors.success, AppColors.success.withOpacity(0.7)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Draw white circle in center
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 5), 18, circlePaint);

    // Draw person icon
    _drawPersonIcon(canvas, Offset(center.dx, center.dy - 5), AppColors.success);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Create a custom dropoff marker
  static Future<BitmapDescriptor> createDropoffMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 120.0;
    const center = Offset(size / 2, size / 2);

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(center.dx, center.dy + 5), 35, shadowPaint);

    // Draw pin shape
    final pinPath = Path();
    pinPath.moveTo(center.dx, center.dy + 35);
    pinPath.quadraticBezierTo(
      center.dx - 30,
      center.dy + 10,
      center.dx - 30,
      center.dy - 15,
    );
    pinPath.arcToPoint(
      Offset(center.dx + 30, center.dy - 15),
      radius: const Radius.circular(30),
    );
    pinPath.quadraticBezierTo(
      center.dx + 30,
      center.dy + 10,
      center.dx,
      center.dy + 35,
    );

    // Draw pin with gradient
    final pinPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - 30, center.dy - 30),
        Offset(center.dx + 30, center.dy + 30),
        [AppColors.error, AppColors.error.withOpacity(0.7)],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(pinPath, pinPaint);

    // Draw white circle in center
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx, center.dy - 5), 18, circlePaint);

    // Draw flag icon
    _drawFlagIcon(canvas, Offset(center.dx, center.dy - 5), AppColors.error);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Draw car icon
  static void _drawCarIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Car body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 45, height: 28),
      const Radius.circular(5),
    );
    canvas.drawRRect(bodyRect, paint);

    // Car roof
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 8),
        width: 28,
        height: 14,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(roofRect, paint);

    // Wheels
    final wheelPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(center.dx - 12, center.dy + 12), 4, wheelPaint);
    canvas.drawCircle(Offset(center.dx + 12, center.dy + 12), 4, wheelPaint);
  }

  /// Draw person icon
  static void _drawPersonIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Head
    canvas.drawCircle(Offset(center.dx, center.dy - 4), 5, paint);

    // Body
    final bodyPath = Path();
    bodyPath.moveTo(center.dx, center.dy + 1);
    bodyPath.lineTo(center.dx - 6, center.dy + 10);
    bodyPath.lineTo(center.dx - 4, center.dy + 10);
    bodyPath.lineTo(center.dx, center.dy + 2);
    bodyPath.lineTo(center.dx + 4, center.dy + 10);
    bodyPath.lineTo(center.dx + 6, center.dy + 10);
    bodyPath.close();

    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bodyPath, bodyPaint);
  }

  /// Draw flag icon
  static void _drawFlagIcon(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Flag pole
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - 8, 2, 16),
      paint,
    );

    // Flag
    final flagPath = Path();
    flagPath.moveTo(center.dx, center.dy - 8);
    flagPath.lineTo(center.dx + 12, center.dy - 4);
    flagPath.lineTo(center.dx, center.dy);
    flagPath.close();
    canvas.drawPath(flagPath, paint);
  }
}

/// Avatar Generator for profiles
class AvatarGenerator {
  /// Generate a circular avatar with initials
  static Widget generateAvatar({
    required String name,
    double size = 80,
    Color? backgroundColor,
  }) {
    final initials = _getInitials(name);
    final bgColor = backgroundColor ?? AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            bgColor,
            bgColor.withOpacity(0.7),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  static String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'DR';
  }
}
