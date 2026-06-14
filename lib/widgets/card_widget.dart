import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CardWidget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? borderRadius;

  const CardWidget({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.white,
          borderRadius: BorderRadius.circular(borderRadius ?? 20),
          border: Border.all(color: AppColors.border.withOpacity(0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withOpacity(0.04),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}