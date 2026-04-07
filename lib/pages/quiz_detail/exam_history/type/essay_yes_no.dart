part of '../../quiz_result_view.dart';

class _EssayYesNoTypeView extends StatelessWidget {
  const _EssayYesNoTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _EssayAnswerTypeView(question: question, answer: answer);
  }
}
