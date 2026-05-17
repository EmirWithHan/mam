import 'package:flutter/material.dart';

import '../constants/sport_types.dart';
import '../theme/app_colors.dart';

class SportIcon extends StatelessWidget {
  const SportIcon({
    super.key,
    this.sportType,
    this.size = 20,
    this.filled = true,
    this.color,
    this.backgroundColor,
  });

  final String? sportType;
  final double size;
  final bool filled;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      sportIconFor(sportType),
      size: size,
      color: color ?? AppColors.primary,
    );

    if (!filled) return icon;

    return Container(
      width: size + 24,
      height: size + 24,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
