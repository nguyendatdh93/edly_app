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
    final prefix = _optionPrefix(index);
    final content = option.content.trim().isNotEmpty
        ? option.content
        : '<p>[Lựa chọn ${index + 1}]</p>';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? const Color(0xFF3B82F6) : Colors.white,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFFD1D5DB),
                    ),
                  ),
                  child: Text(
                    prefix,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: selected ? Colors.white : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Center(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DefaultRoomHtmlView(
                    html: content,
                    fontSize: 10,
                    minHeight: 28,
                    maxAutoHeight: 320,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
