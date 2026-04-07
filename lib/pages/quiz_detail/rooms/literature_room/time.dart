import 'package:flutter/material.dart';

class LiteratureRoomTime extends StatelessWidget {
  const LiteratureRoomTime({
    super.key,
    required this.value,
    this.compact = false,
    this.highlight = false,
  });

  final String value;
  final bool compact;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFEF3C7) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF334155)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFF92400E)
                  : const Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
