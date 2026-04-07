part of '../../quiz_result_view.dart';

class _ComprehensionTypeView extends StatelessWidget {
  const _ComprehensionTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _OptionListTypeView(
      title: 'Đáp án đọc hiểu:',
      question: question,
      answer: answer,
    );
  }
}
