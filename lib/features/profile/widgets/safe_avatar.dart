import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';

class SafeAvatar extends StatelessWidget {
  const SafeAvatar({
    super.key,
    required this.radius,
    this.avatarUrl,
    this.imageBytes,
    this.fallbackText = 'M',
    this.fallbackIcon,
    this.backgroundColor = AppColors.primarySoft,
    this.foregroundColor = AppColors.primary,
    this.fontSize,
  });

  final double radius;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final String fallbackText;
  final IconData? fallbackIcon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final url = avatarUrl?.trim();
    final bytes = imageBytes;

    return SizedBox.square(
      dimension: diameter,
      child: ClipOval(
        child: ColoredBox(
          color: backgroundColor,
          child: bytes != null
              ? Image.memory(
                  bytes,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                )
              : url != null && url.isNotEmpty
              ? Image.network(
                  url,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _fallback(context),
                )
              : _fallback(context),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final icon = fallbackIcon;
    if (icon != null) {
      return Icon(icon, color: foregroundColor, size: radius * 0.96);
    }

    return Center(child: AppLogo(size: radius * 1.2));
  }
}
