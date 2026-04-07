import 'package:flutter/material.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/time.dart';

class TsaIntroCard extends StatelessWidget {
  const TsaIntroCard({
    super.key,
    required this.moduleName,
    required this.minute,
    required this.onStart,
    required this.moduleIndexText,
  });

  final String moduleName;
  final int minute;
  final String moduleIndexText;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moduleIndexText,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  moduleName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thời gian làm bài: $minute phút',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Bắt đầu module'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TsaRoomHeader extends StatelessWidget {
  const TsaRoomHeader({
    super.key,
    required this.quizName,
    required this.moduleName,
    required this.timerText,
    required this.answeredText,
  });

  final String quizName;
  final String moduleName;
  final String timerText;
  final String answeredText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B4DA1),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  moduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDBEAFE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TsaRoomTime(value: timerText, compact: true, highlight: true),
          const SizedBox(width: 6),
          _TsaBadge(label: answeredText, icon: Icons.fact_check_outlined),
        ],
      ),
    );
  }
}

class _TsaBadge extends StatelessWidget {
  const _TsaBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
