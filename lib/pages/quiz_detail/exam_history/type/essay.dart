part of '../../quiz_result_view.dart';

class _EssayTypeView extends StatelessWidget {
  const _EssayTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _EssayAnswerTypeView(question: question, answer: answer);
  }
}

class _EssayAnswerTypeView extends StatelessWidget {
  const _EssayAnswerTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    final userAnswer = _userAnswerOf(question, answer);
    final isEmpty = userAnswer == '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Câu trả lời của bạn:',
          style: TextStyle(
            color: QuizDetailPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Text(
            userAnswer,
            style: TextStyle(
              color: isEmpty
                  ? const Color(0xFF94A3B8)
                  : QuizDetailPalette.textPrimary,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}
