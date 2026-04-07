import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
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
    final prefix = String.fromCharCode(65 + index);
    final content = stripHtml(option.content);
    final label = content.isNotEmpty
        ? '$prefix. $content'
        : '$prefix. [Lựa chọn ${index + 1}]';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
