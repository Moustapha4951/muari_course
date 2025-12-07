import 'package:flutter/material.dart';
import 'package:rimapp_driver/utils/app_theme.dart';

class LocationMarkerIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const LocationMarkerIcon({
    super.key,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LocationMarkerPainter(
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }
}

class _LocationMarkerPainter extends CustomPainter {
  final Color color;

  _LocationMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Draw a pin shape
    path.moveTo(size.width * 0.5, size.height);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.7,
      size.width * 0.9,
      size.height * 0.4,
    );
    path.arcToPoint(
      Offset(size.width * 0.1, size.height * 0.4),
      radius: Radius.circular(size.width * 0.4),
      clockwise: false,
    );
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.7,
      size.width * 0.5,
      size.height,
    );
    
    // Shadow/Hole
    canvas.drawShadow(path, Colors.black, 4, true);
    canvas.drawPath(path, paint);

    // Center dot
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.4),
      size.width * 0.15,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StartLocationIcon extends StatelessWidget {
  final double size;

  const StartLocationIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.secondary,
          width: size * 0.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class EndLocationIcon extends StatelessWidget {
  final double size;

  const EndLocationIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.rectangle, // Square for end
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(
          color: AppColors.primary,
          width: size * 0.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.4,
          height: size * 0.4,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(size * 0.1),
          ),
        ),
      ),
    );
  }
}
