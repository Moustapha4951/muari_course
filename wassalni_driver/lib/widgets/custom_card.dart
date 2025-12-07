import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Modern Custom Card with multiple variants
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final CardVariant variant;
  final Color? customColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.variant = CardVariant.elevated,
    this.customColor,
    this.elevation,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(AppRadius.xxl);
    final effectivePadding = padding ?? const EdgeInsets.all(AppSpacing.lg);
    final effectiveMargin = margin ?? const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );

    Widget cardContent = Container(
      padding: effectivePadding,
      decoration: _getDecoration(effectiveBorderRadius),
      child: child,
    );

    if (onTap != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: cardContent,
        ),
      );
    }

    return Container(
      margin: effectiveMargin,
      child: cardContent,
    );
  }

  BoxDecoration _getDecoration(BorderRadius borderRadius) {
    switch (variant) {
      case CardVariant.elevated:
        return BoxDecoration(
          color: customColor ?? AppColors.surface,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.08),
              blurRadius: elevation ?? 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        );
      case CardVariant.outlined:
        return BoxDecoration(
          color: customColor ?? AppColors.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
        );
      case CardVariant.filled:
        return BoxDecoration(
          color: customColor ?? AppColors.surfaceVariant,
          borderRadius: borderRadius,
        );
      case CardVariant.gradient:
        return BoxDecoration(
          gradient: customColor != null
              ? LinearGradient(
                  colors: [customColor!, customColor!.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : AppColors.primaryGradient,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: (customColor ?? AppColors.primary).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        );
      case CardVariant.glass:
        return BoxDecoration(
          color: (customColor ?? AppColors.surface).withOpacity(0.7),
          borderRadius: borderRadius,
          border: Border.all(
            color: AppColors.surface.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        );
    }
  }
}

enum CardVariant {
  elevated,
  outlined,
  filled,
  gradient,
  glass,
}

/// Info Card with icon and text
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const InfoCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onTap,
      variant: CardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: (backgroundColor ?? AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
        ],
      ),
    );
  }
}

/// Status Badge
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    Key? key,
    required this.text,
    required this.color,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
