import 'package:flutter/material.dart';
import '../constants/colors.dart';

class OfficialCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color borderColor;
  final Color backgroundColor;
  final double borderRadius;

  const OfficialCard({
    Key? key,
    required this.title,
    required this.child,
    this.trailing,
    this.borderColor = AppColors.glassBorder,
    this.backgroundColor = AppColors.glassCard,
    this.borderRadius = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1.0),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            if (title.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.neutralPill.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(color: borderColor.withOpacity(0.5), width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMain,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
