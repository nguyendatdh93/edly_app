part of '../../quiz_result_view.dart';

class _MultipleChoicesTypeView extends StatelessWidget {
  const _MultipleChoicesTypeView({
    required this.question,
    required this.answer,
  });

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _OptionListTypeView(
      title: 'Lựa chọn nhiều đáp án:',
      question: question,
      answer: answer,
    );
  }
}
