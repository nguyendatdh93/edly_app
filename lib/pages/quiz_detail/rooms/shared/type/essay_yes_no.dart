import 'package:edupen/pages/quiz_detail/rooms/shared/type/essay.dart';
import 'package:flutter/material.dart';

class EssayYesNo extends StatelessWidget {
  const EssayYesNo({
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
      hintText: 'Nhập câu trả lời cho dạng đúng/sai tự luận',
      onChanged: onChanged,
      minLines: 3,
      maxLines: 6,
    );
  }
}
