import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final String? icon;
  final String? variant; // primary, green, outline, ghost, accent, danger
  final bool disabled;
  final bool loading;

  const ButtonWidget({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.variant = 'primary',
    this.disabled = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, ButtonStyle> styles = {
      'primary': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.forest),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
      ),
      'green': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.green),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
      ),
      'outline': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        foregroundColor: WidgetStateProperty.all(AppColors.green),
        side: WidgetStateProperty.all(BorderSide(color: AppColors.green, width: 1.5)),
      ),
      'ghost': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.bgDeep),
        foregroundColor: WidgetStateProperty.all(AppColors.text),
        side: WidgetStateProperty.all(BorderSide(color: AppColors.border, width: 1)),
      ),
      'accent': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.accent),
        foregroundColor: WidgetStateProperty.all(AppColors.white),
      ),
      'danger': ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.dangerPale),
        foregroundColor: WidgetStateProperty.all(AppColors.danger),
        side: WidgetStateProperty.all(BorderSide(color: AppColors.danger.withOpacity(0.27), width: 1)),
      ),
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: variant == 'primary' || variant == 'green'
            ? LinearGradient(
                colors: variant == 'primary' 
                    ? [AppColors.forest, AppColors.forest.withOpacity(0.85)]
                    : [AppColors.green, AppColors.greenL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: (variant == 'primary' || variant == 'green' || variant == 'accent') && !disabled
            ? [
                BoxShadow(
                  color: (variant == 'primary' ? AppColors.forest : variant == 'green' ? AppColors.green : AppColors.accent).withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        style: styles[variant]?.copyWith(
          backgroundColor: (variant == 'primary' || variant == 'green') ? WidgetStateProperty.all(Colors.transparent) : null,
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
        ),
        child: loading 
          ? const SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Text(icon!, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}