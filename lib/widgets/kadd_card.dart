import 'package:flutter/material.dart';
import '../theme.dart';

/// The `.app-row` / `.settings-list` card style from kadd-mockups.html,
/// centralized so every screen shares identical radius/border/spacing
/// instead of each one redeclaring a slightly-different BoxDecoration.
class KaddCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const KaddCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// The pill-shaped primary CTA button style (`.ring-cta` / `.prayer-cta` in
/// the mockup) — signal-orange fill, dark text, fully rounded.
class KaddPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  const KaddPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.signal,
        disabledBackgroundColor: AppColors.signal.withOpacity(0.35),
        padding: padding,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      onPressed: onPressed,
      child: Text(label, style: AppTextStyles.kufi(size: 14, color: const Color(0xFF1A0D08))),
    );
  }
}
