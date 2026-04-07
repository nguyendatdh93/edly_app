import 'package:flutter/material.dart';

class LiteratureRoomHeader extends StatelessWidget {
  const LiteratureRoomHeader({
    super.key,
    required this.title,
    required this.timer,
    required this.answered,
  });

  final String title;
  final String timer;
  final String answered;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timer,
            style: const TextStyle(
              color: Color(0xFFFACC15),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            answered,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class LiteratureSubmitBar extends StatelessWidget {
  const LiteratureSubmitBar({
    super.key,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final VoidCallback onSubmit;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isSubmitting ? null : onSubmit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(isSubmitting ? 'Đang nộp bài...' : 'Nộp bài'),
        ),
      ),
    );
  }
}
