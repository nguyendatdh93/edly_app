import 'package:flutter/material.dart';
import 'package:edupen/pages/quiz_detail/rooms/vact_room/time.dart';

class VactPreviewCard extends StatelessWidget {
  const VactPreviewCard({
    super.key,
    required this.quizName,
    required this.moduleNames,
    required this.onStart,
  });

  final String quizName;
  final List<String> moduleNames;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Card(
          margin: const EdgeInsets.all(18),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bài thi gồm nhiều phần, tổng thời gian làm bài 150 phút.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ...List<Widget>.generate(moduleNames.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '- ${moduleNames[index]}',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Bắt đầu thi V-ACT'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VactRoomHeader extends StatelessWidget {
  const VactRoomHeader({
    super.key,
    required this.quizName,
    required this.timerText,
    required this.answeredText,
  });

  final String quizName;
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
            child: Text(
              quizName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          VactRoomTime(value: timerText, compact: true, highlight: true),
          const SizedBox(width: 12),
          Text(
            answeredText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
