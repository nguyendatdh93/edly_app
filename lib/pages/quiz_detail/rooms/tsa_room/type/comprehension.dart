import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/type/essay.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/type/single_choice.dart';
import 'package:flutter/material.dart';

class Comprehension extends StatelessWidget {
  const Comprehension({
    super.key,
    required this.question,
    required this.selectedOptionId,
    required this.textValue,
    required this.onSelect,
    required this.onTextChanged,
  });

  final QuizQuestion question;
  final String selectedOptionId;
  final String textValue;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    if (question.options.isNotEmpty) {
      return SingleChoice(
        question: question,
        selectedOptionId: selectedOptionId,
        onSelect: onSelect,
      );
    }

    return Essay(
      questionId: question.id,
      initialValue: textValue,
      hintText: 'Nhập câu trả lời cho câu đọc hiểu',
      onChanged: onTextChanged,
    );
  }
}
