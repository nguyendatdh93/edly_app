import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:flutter/material.dart';

class DefaultRoomNavigate extends StatelessWidget {
  const DefaultRoomNavigate({
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
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isCurrent = index == currentIndex;
          final isAnswered = answerState.isQuestionAnswered(questions[index]);
          final isMarked =
              showMarked && answerState.isMarked(questions[index].id);

          final style = _resolveStyle(
            isCurrent: isCurrent,
            isAnswered: isAnswered,
            isMarked: isMarked,
          );

          return InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle, // đảm bảo tròn tuyệt đối
                color: style.background,
                border: Border.all(color: style.border),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: style.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 12, // nhỏ lại cho cân
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _DefaultNavStyle _resolveStyle({
    required bool isCurrent,
    required bool isAnswered,
    required bool isMarked,
  }) {
    if (isMarked) {
      return const _DefaultNavStyle(
        background: Color(0xFFFED7AA),
        foreground: Color(0xFFEA580C),
        border: Color(0xFFF97316),
      );
    }
    if (isAnswered) {
      return const _DefaultNavStyle(
        background: Color(0xFFBFDBFE),
        foreground: Color(0xFF2563EB),
        border: Color(0xFF3B82F6),
      );
    }
    if (isCurrent) {
      return const _DefaultNavStyle(
        background: Color(0xFF9CA3AF),
        foreground: Colors.white,
        border: Color(0xFFD1D5DB),
      );
    }
    return const _DefaultNavStyle(
      background: Color(0xFFE5E7EB),
      foreground: Color(0xFF374151),
      border: Color(0xFFE5E7EB),
    );
  }
}

class _DefaultNavStyle {
  const _DefaultNavStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
