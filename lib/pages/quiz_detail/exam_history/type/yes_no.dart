part of '../../quiz_result_view.dart';

class _YesNoTypeView extends StatelessWidget {
  const _YesNoTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    if (question.options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đánh dấu Đúng / Sai:',
          style: TextStyle(
            color: QuizDetailPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(question.options.length, (index) {
          final option = question.options[index];
          final userValue = _resolveYesNoUserValue(answer, option.id);
          final expectedValue = option.isCorrect;
          final answered = userValue != null;
          final isCorrect = answered && userValue == expectedValue;

          final background = !answered
              ? const Color(0xFFF8FAFC)
              : isCorrect
              ? const Color(0xFFECFDF3)
              : const Color(0xFFFEF2F2);
          final border = !answered
              ? const Color(0xFFD0D5DD)
              : isCorrect
              ? const Color(0xFF86EFAC)
              : const Color(0xFFFCA5A5);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${String.fromCharCode(97 + index)})',
                        style: const TextStyle(
                          color: QuizDetailPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _QuizContentView(
                          question: question,
                          option: option,
                          raw: option.content,
                          style: const TextStyle(
                            color: QuizDetailPalette.textPrimary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          maxImageHeight: 120,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _YesNoPill(
                        label: 'Bạn chọn',
                        value: userValue == null
                            ? '-'
                            : userValue
                            ? 'Đúng'
                            : 'Sai',
                        foreground: userValue == null
                            ? const Color(0xFF64748B)
                            : isCorrect
                            ? const Color(0xFF166534)
                            : const Color(0xFF991B1B),
                        background: userValue == null
                            ? const Color(0xFFE2E8F0)
                            : isCorrect
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                      ),
                      _YesNoPill(
                        label: 'Đáp án',
                        value: expectedValue ? 'Đúng' : 'Sai',
                        foreground: const Color(0xFF166534),
                        background: const Color(0xFFDCFCE7),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _YesNoPill extends StatelessWidget {
  const _YesNoPill({
    required this.label,
    required this.value,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String value;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
