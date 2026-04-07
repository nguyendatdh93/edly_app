import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
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
          CheckboxListTile(
            value: selected.contains(question.options[index].id),
            contentPadding: EdgeInsets.zero,
            title: Text(_optionLabel(index, question.options[index])),
            onChanged: (checked) {
              onToggle(question.options[index].id, checked == true);
            },
          ),
      ],
    );
  }

  String _optionLabel(int index, QuizOption option) {
    final content = stripHtml(option.content);
    final prefix = String.fromCharCode(65 + index);
    if (content.isEmpty) {
      return '$prefix. [Lựa chọn ${index + 1}]';
    }
    return '$prefix. $content';
  }
}
