import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Shows a real installed-app icon (from AppState's cache) when available,
/// falling back to a generic lock glyph — e.g. for an app that was locked
/// and later uninstalled, or while the installed-apps list is still loading.
class AppIcon extends StatelessWidget {
  final Uint8List? iconBytes;
  final double size;

  const AppIcon({super.key, required this.iconBytes, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: size,
        height: size,
        color: AppColors.surface2,
        alignment: Alignment.center,
        child: iconBytes != null
            ? Image.memory(iconBytes!, width: size, height: size, fit: BoxFit.cover)
            : Icon(Icons.lock_outline, size: size * 0.5, color: AppColors.textFaint),
      ),
    );
  }
}
