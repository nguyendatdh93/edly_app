import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/widgets/html_math_view.dart';
import 'package:flutter/material.dart';

class SingleChoice extends StatelessWidget {
  const SingleChoice({
    super.key,
    required this.question,
    required this.selectedOptionId,
    required this.onSelect,
  });

  final QuizQuestion question;
  final String selectedOptionId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < question.options.length; index++)
          _SingleChoiceOption(
            index: index,
            option: question.options[index],
            selected: selectedOptionId == question.options[index].id,
            onTap: () => onSelect(question.options[index].id),
          ),
      ],
    );
  }
}

class _SingleChoiceOption extends StatelessWidget {
  const _SingleChoiceOption({
    required this.index,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final QuizOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = option.content.trim().isNotEmpty
        ? option.content
        : '<p>[Lựa chọn ${index + 1}]</p>';
    final state = _resolveState(selected);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: state.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: state.borderColor,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: state.borderColor),
              ),
              child: Text(
                _optionPrefix(index),
                style: TextStyle(
                  color: state.labelColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: IgnorePointer(
                child: DefaultRoomHtmlView(
                  html: content,
                  fontSize: 15,
                  minHeight: 26,
                  maxAutoHeight: 320,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _SingleChoiceOptionState _resolveState(bool selected) {
    if (selected) {
      return const _SingleChoiceOptionState(
        backgroundColor: Color(0xFFEEF2FF),
        borderColor: Color(0xFF2563EB),
        labelColor: Color(0xFF2563EB),
      );
    }

    return const _SingleChoiceOptionState(
      backgroundColor: Color(0xFFF8FAFC),
      borderColor: Color(0xFFCBD5E1),
      labelColor: Color(0xFF334155),
    );
  }

  String _optionPrefix(int optionIndex) {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    if (optionIndex >= 0 && optionIndex < labels.length) {
      return labels[optionIndex];
    }
    return String.fromCharCode(65 + optionIndex);
  }
}

class _SingleChoiceOptionState {
  const _SingleChoiceOptionState({
    required this.backgroundColor,
    required this.borderColor,
    required this.labelColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color labelColor;
}
