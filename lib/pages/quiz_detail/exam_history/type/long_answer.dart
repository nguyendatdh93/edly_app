part of '../../quiz_result_view.dart';

class _LongAnswerTypeView extends StatelessWidget {
  const _LongAnswerTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _EssayAnswerTypeView(question: question, answer: answer);
  }
}
