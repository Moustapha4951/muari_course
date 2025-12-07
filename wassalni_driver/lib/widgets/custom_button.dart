import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Modern Custom Button with multiple variants
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? customColor;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.customColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final height = _getHeight();
    final padding = _getPadding();
    final fontSize = _getFontSize();

    if (variant == ButtonVariant.gradient) {
      return _buildGradientButton(height, padding, fontSize);
    }

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: _getButtonStyle(padding),
        child: _buildButtonChild(fontSize),
      ),
    );
  }

  Widget _buildGradientButton(double height, EdgeInsets padding, double fontSize) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: height,
      decoration: BoxDecoration(
        gradient: customColor != null
            ? LinearGradient(
                colors: [customColor!, customColor!.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: (customColor ?? AppColors.primary).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: padding,
            child: _buildButtonChild(fontSize, forceWhite: true),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonChild(double fontSize, {bool forceWhite = false}) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            forceWhite || variant == ButtonVariant.primary || variant == ButtonVariant.gradient
                ? Colors.white
                : AppColors.primary,
          ),
        ),
      );
    }

    final textWidget = Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: _getTextColor(forceWhite),
        letterSpacing: 0.5,
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: fontSize + 4, color: _getTextColor(forceWhite)),
          const SizedBox(width: 12),
          textWidget,
        ],
      );
    }

    return Center(child: textWidget);
  }

  ButtonStyle _getButtonStyle(EdgeInsets padding) {
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: (customColor ?? AppColors.primary).withOpacity(0.4),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
      case ButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? AppColors.secondary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: (customColor ?? AppColors.secondary).withOpacity(0.4),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
      case ButtonVariant.outline:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: customColor ?? AppColors.primary,
          elevation: 0,
          side: BorderSide(
            color: customColor ?? AppColors.primary,
            width: 2,
          ),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
      case ButtonVariant.text:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: customColor ?? AppColors.primary,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
      case ButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          backgroundColor: (customColor ?? AppColors.primary).withOpacity(0.1),
          foregroundColor: customColor ?? AppColors.primary,
          elevation: 0,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
      default:
        return ElevatedButton.styleFrom(
          backgroundColor: customColor ?? AppColors.primary,
          foregroundColor: Colors.white,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        );
    }
  }

  Color _getTextColor(bool forceWhite) {
    if (forceWhite) return Colors.white;
    
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.secondary:
      case ButtonVariant.gradient:
        return Colors.white;
      case ButtonVariant.outline:
      case ButtonVariant.text:
      case ButtonVariant.ghost:
        return customColor ?? AppColors.primary;
    }
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.small:
        return 44;
      case ButtonSize.medium:
        return 52;
      case ButtonSize.large:
        return 60;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
    }
  }

  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return 14;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.large:
        return 18;
    }
  }
}

enum ButtonVariant {
  primary,
  secondary,
  outline,
  text,
  ghost,
  gradient,
}

enum ButtonSize {
  small,
  medium,
  large,
}
