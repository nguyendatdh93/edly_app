import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:flutter/material.dart';

class YesNo extends StatelessWidget {
  const YesNo({
    super.key,
    required this.question,
    required this.values,
    required this.onToggle,
  });

  final QuizQuestion question;
  final Map<String, bool> values;
  final void Function(String optionId, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < question.options.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(_optionLabel(index, question.options[index])),
                ),
                Switch(
                  value: values[question.options[index].id] == true,
                  onChanged: (checked) {
                    onToggle(question.options[index].id, checked);
                  },
                ),
              ],
            ),
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
