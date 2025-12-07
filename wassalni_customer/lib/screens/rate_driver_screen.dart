import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_theme.dart';

class RateDriverScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String driverName;

  const RateDriverScreen({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);

    try {
      // Update ride with rating
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'customerRating': _rating,
        'customerComment': _commentController.text.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // Update driver's average rating
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .get();

      if (driverDoc.exists) {
        final driverData = driverDoc.data()!;
        final currentRating = (driverData['rating'] ?? 0.0).toDouble();
        final totalRatings = (driverData['totalRatings'] ?? 0) as int;
        
        final newTotalRatings = totalRatings + 1;
        final newRating = ((currentRating * totalRatings) + _rating) / newTotalRatings;

        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(widget.driverId)
            .update({
          'rating': newRating,
          'totalRatings': newTotalRatings,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً لتقييمك'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إرسال التقييم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'تقييم السائق',
          style: AppTextStyles.arabicTitle,
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Driver Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.driverName,
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كيف كانت تجربتك مع هذا السائق؟',
                    style: AppTextStyles.arabicBody.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Rating Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'التقييم',
                    style: AppTextStyles.arabicTitle.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _rating = (index + 1).toDouble();
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 48,
                            color: AppColors.warning,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // Rating Text
                  Text(
                    _getRatingText(_rating),
                    style: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Comment Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعليق (اختياري)',
                    style: AppTextStyles.arabicBody.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    textDirection: TextDirection.rtl,
                    style: AppTextStyles.arabicBody,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'اكتب تعليقك هنا...',
                      hintStyle: AppTextStyles.arabicBody.copyWith(
                        color: AppColors.textHint,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRating,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmitting ? 'جاري الإرسال...' : 'إرسال التقييم',
                style: AppTextStyles.arabicTitle.copyWith(
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Skip Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'تخطي',
                style: AppTextStyles.arabicBody.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'ممتاز';
    if (rating >= 4) return 'جيد جداً';
    if (rating >= 3) return 'جيد';
    if (rating >= 2) return 'مقبول';
    return 'ضعيف';
  }
}
