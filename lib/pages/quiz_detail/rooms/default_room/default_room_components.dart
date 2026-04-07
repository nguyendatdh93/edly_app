import 'package:flutter/material.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/time.dart';

class DefaultRoomHeader extends StatelessWidget {
  const DefaultRoomHeader({
    super.key,
    required this.title,
    required this.timerText,
    required this.answeredText,
  });

  final String title;
  final String timerText;
  final String answeredText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B4DA1), Color(0xFF1D4ED8)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          DefaultRoomTime(value: timerText, compact: true),
          const SizedBox(width: 8),
          _InfoBadge(icon: Icons.edit_note_rounded, text: answeredText),
        ],
      ),
    );
  }
}

class DefaultRoomFooter extends StatelessWidget {
  const DefaultRoomFooter({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmit,
    required this.canPrevious,
    required this.isLastQuestion,
    required this.isSubmitting,
  });

  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  final bool canPrevious;
  final bool isLastQuestion;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: canPrevious ? onPrevious : null,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Câu trước'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: isSubmitting
                  ? null
                  : (isLastQuestion ? onSubmit : onNext),
              icon: Icon(
                isLastQuestion
                    ? Icons.send_rounded
                    : Icons.arrow_forward_rounded,
              ),
              label: Text(isLastQuestion ? 'Nộp bài' : 'Câu tiếp'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
