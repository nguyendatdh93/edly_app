import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/essay.dart';
import 'package:flutter/material.dart';

class LongAnswer extends StatelessWidget {
  const LongAnswer({
    super.key,
    required this.questionId,
    required this.initialValue,
    required this.onChanged,
  });

  final String questionId;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Essay(
      questionId: questionId,
      initialValue: initialValue,
      hintText: 'Nhập câu trả lời dài của bạn',
      onChanged: onChanged,
      minLines: 5,
      maxLines: 10,
    );
  }
}
