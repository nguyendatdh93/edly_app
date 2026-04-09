import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/widgets/html_math_view.dart';
import 'package:flutter/material.dart';

class MultipleChoices extends StatelessWidget {
  const MultipleChoices({
    super.key,
    required this.question,
    required this.selected,
    required this.onToggle,
  });

  final QuizQuestion question;
  final Set<String> selected;
  final void Function(String optionId, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < question.options.length; index++)
          _MultipleChoiceOption(
            html: _optionHtml(index, question.options[index]),
            checked: selected.contains(question.options[index].id),
            onTap: () {
              final isChecked = selected.contains(question.options[index].id);
              onToggle(question.options[index].id, !isChecked);
            },
          ),
      ],
    );
  }

  String _optionHtml(int index, QuizOption option) {
    if (option.content.trim().isEmpty) {
      return '<p>[Lựa chọn ${index + 1}]</p>';
    }
    return option.content;
  }
}

class _MultipleChoiceOption extends StatelessWidget {
  const _MultipleChoiceOption({
    required this.html,
    required this.checked,
    required this.onTap,
  });

  final String html;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: checked ? const Color(0xFFBFDBFE) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: checked
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DefaultRoomHtmlView(
                html: html,
                fontSize: 16,
                minHeight: 26,
                maxAutoHeight: 320,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
