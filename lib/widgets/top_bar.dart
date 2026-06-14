import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? right;

  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.7), width: 1)),
        boxShadow: [
          BoxShadow(color: AppColors.forest.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('‹', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'DM Serif Display',
                fontSize: 24,
                color: AppColors.text,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (right != null) right!,
        ],
      ),
    );
  }
}