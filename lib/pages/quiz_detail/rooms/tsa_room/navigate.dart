import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:flutter/material.dart';

class TsaRoomNavigate extends StatelessWidget {
  const TsaRoomNavigate({
    super.key,
    required this.questions,
    required this.currentIndex,
    required this.answerState,
    required this.onTap,
    this.showMarked = true,
  });

  final List<QuizQuestion> questions;
  final int currentIndex;
  final QuizRoomAnswerState answerState;
  final ValueChanged<int> onTap;
  final bool showMarked;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(questions.length, (index) {
        final isCurrent = index == currentIndex;
        final isAnswered = answerState.isQuestionAnswered(questions[index]);
        final isMarked =
            showMarked && answerState.isMarked(questions[index].id);

        final color = isCurrent
            ? const Color(0xFF1D4ED8)
            : isMarked
            ? const Color(0xFFF97316)
            : isAnswered
            ? const Color(0xFF0EA5E9)
            : const Color(0xFFE2E8F0);

        return InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isCurrent || isMarked || isAnswered
                    ? Colors.white
                    : const Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }),
    );
  }
}
