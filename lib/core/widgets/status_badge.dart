import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color contentColor;
  final bool uppercase;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    Key? key,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    this.contentColor = Colors.white,
    this.uppercase = true,
    this.fontSize = 11,
    this.iconSize = 13,
    this.padding,
  }) : super(key: key);

  factory StatusBadge.verified({String label = 'VERIFIED'}) {
    return StatusBadge(
      label: label,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFFDCFCE7),
      contentColor: const Color(0xFF15803D),
    );
  }

  factory StatusBadge.alert({String label = 'ALERT'}) {
    return StatusBadge(
      label: label,
      icon: Icons.warning_rounded,
      backgroundColor: const Color(0xFFFEE2E2),
      contentColor: const Color(0xFFB91C1C),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: contentColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    letterSpacing: 0.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
