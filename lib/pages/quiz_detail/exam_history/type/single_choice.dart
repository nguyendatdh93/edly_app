part of '../../quiz_result_view.dart';

class _ExamHistoryTypeView extends StatelessWidget {
  const _ExamHistoryTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    final type = question.type.toLowerCase().trim();

    switch (type) {
      case 'single-choice':
        return _SingleChoiceTypeView(question: question, answer: answer);
      case 'multiple-choices':
        return _MultipleChoicesTypeView(question: question, answer: answer);
      case 'yes-no':
        return _YesNoTypeView(question: question, answer: answer);
      case 'drag-drop':
        return _DragDropTypeView(question: question, answer: answer);
      case 'essay':
        return _EssayTypeView(question: question, answer: answer);
      case 'essay-yes-no':
        return _EssayYesNoTypeView(question: question, answer: answer);
      case 'long-answer':
      case 'short-answer':
      case 'numeric':
        return _LongAnswerTypeView(question: question, answer: answer);
      case 'comprehension':
        return _ComprehensionTypeView(question: question, answer: answer);
      default:
        if (question.options.isNotEmpty) {
          return _SingleChoiceTypeView(question: question, answer: answer);
        }
        return _EssayTypeView(question: question, answer: answer);
    }
  }
}

class _SingleChoiceTypeView extends StatelessWidget {
  const _SingleChoiceTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    return _OptionListTypeView(
      title: 'Các đáp án:',
      question: question,
      answer: answer,
    );
  }
}

class _OptionListTypeView extends StatelessWidget {
  const _OptionListTypeView({
    required this.title,
    required this.question,
    required this.answer,
  });

  final String title;
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
        Text(
          title,
          style: const TextStyle(
            color: QuizDetailPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(question.options.length, (index) {
          final option = question.options[index];
          final optionState = _optionState(question, option, answer);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: optionState.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: optionState.border, width: 1.6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_optionLabel(index)}.',
                    style: TextStyle(
                      color: optionState.labelColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuizContentView(
                      question: question,
                      option: option,
                      raw: option.content,
                      style: TextStyle(
                        color: optionState.contentColor,
                        fontSize: 16,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                      maxImageHeight: 120,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (option.isCorrect)
                    const _OptionFlag(
                      icon: Icons.check_circle_rounded,
                      label: 'Đáp án đúng',
                      color: Color(0xFF10B981),
                    )
                  else if (_isUserSelectedOption(answer, option))
                    const _OptionFlag(
                      icon: Icons.cancel_rounded,
                      label: 'Bạn chọn',
                      color: Color(0xFFFF1F5B),
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
