import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTheme {
  static TextStyle heading1({Color color = AppColors.text}) => TextStyle(
    fontFamily: 'DM Serif Display', fontSize: 32, color: color, height: 1.15,
    letterSpacing: -0.5,
  );
  static TextStyle heading2({Color color = AppColors.text}) => TextStyle(
    fontFamily: 'DM Serif Display', fontSize: 24, color: color, height: 1.2,
  );
  static TextStyle heading3({Color color = AppColors.text}) => TextStyle(
    fontFamily: 'DM Serif Display', fontSize: 19, color: color, height: 1.25,
  );
  static TextStyle label({Color color = AppColors.sub}) => TextStyle(
    fontSize: 11, color: color, fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
  static TextStyle body({Color color = AppColors.text}) => TextStyle(
    fontSize: 14, color: color, height: 1.5,
  );
  static TextStyle bodySmall({Color color = AppColors.sub}) => TextStyle(
    fontSize: 12, color: color, height: 1.4,
  );
  static TextStyle caption({Color color = AppColors.sub}) => TextStyle(
    fontSize: 11, color: color, height: 1.4,
  );

  static BoxDecoration cardDecoration({Color? color, double radius = 18}) =>
    BoxDecoration(
      color: color ?? AppColors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border.withOpacity(0.8), width: 1.2),
      boxShadow: [
        BoxShadow(color: AppColors.forest.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
      ],
    );

  static BoxDecoration gradientDecoration({
    List<Color>? colors,
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    double radius = 0,
  }) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors ?? [AppColors.forest, AppColors.green],
    ),
    borderRadius: radius > 0
      ? BorderRadius.circular(radius)
      : BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: Radius.circular(topRight),
          bottomLeft: Radius.circular(bottomLeft),
          bottomRight: Radius.circular(bottomRight),
        ),
  );
}
