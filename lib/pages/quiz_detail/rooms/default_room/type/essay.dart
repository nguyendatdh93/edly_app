import 'package:flutter/material.dart';

class Essay extends StatelessWidget {
  const Essay({
    super.key,
    required this.questionId,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
    this.minLines = 3,
    this.maxLines = 6,
  });

  final String questionId;
  final String initialValue;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: ValueKey<String>('essay-$questionId'),
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
      ),
      onChanged: onChanged,
    );
  }
}
