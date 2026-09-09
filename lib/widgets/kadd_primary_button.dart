import 'package:flutter/material.dart';
import '../theme.dart';

class KaddPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const KaddPrimaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.unlock,
          foregroundColor: const Color(0xFF1A1F0A),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: const Color(0xFF1A1F0A)),
        ),
      ),
    );
  }
}
