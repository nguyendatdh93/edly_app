part of '../../quiz_result_view.dart';

class _DragDropTypeView extends StatelessWidget {
  const _DragDropTypeView({required this.question, required this.answer});

  final QuizQuestion question;
  final Map<String, dynamic>? answer;

  @override
  Widget build(BuildContext context) {
    final optionById = <String, QuizOption>{
      for (final option in question.options)
        if (option.id.trim().isNotEmpty) option.id.trim(): option,
    };

    final selectedIds = _readSelectedIds();
    final selectedTexts = selectedIds
        .map((id) => optionById[id])
        .whereType<QuizOption>()
        .map((option) => _stripHtml(option.content))
        .where((value) => value.isNotEmpty)
        .toList();

    final correctOptions = question.options
        .where((option) => option.isCorrect)
        .toList();
    final normalizedCorrect = correctOptions.isNotEmpty
        ? correctOptions
        : question.options;
    final correctTexts = normalizedCorrect
        .map((option) => _stripHtml(option.content))
        .where((value) => value.isNotEmpty)
        .toList();

    final correctIds = normalizedCorrect
        .map((option) => option.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final isExactCorrect =
        selectedIds.length == correctIds.length &&
        selectedIds.asMap().entries.every((entry) {
          if (entry.key >= correctIds.length) {
            return false;
          }
          return entry.value == correctIds[entry.key];
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kết quả kéo thả:',
          style: TextStyle(
            color: QuizDetailPalette.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        if (selectedIds.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: const Text(
              'Bạn chưa kéo thả đáp án cho câu này.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          _DragDropAnswerBox(
            title: 'Bạn đã điền',
            items: selectedTexts,
            foreground: isExactCorrect
                ? const Color(0xFF166534)
                : const Color(0xFF9F1239),
            background: isExactCorrect
                ? const Color(0xFFECFDF3)
                : const Color(0xFFFFF1F3),
            border: isExactCorrect
                ? const Color(0xFF86EFAC)
                : const Color(0xFFFDA4AF),
          ),
        const SizedBox(height: 10),
        _DragDropAnswerBox(
          title: 'Đáp án đúng',
          items: correctTexts,
          foreground: const Color(0xFF166534),
          background: const Color(0xFFECFDF3),
          border: const Color(0xFF86EFAC),
        ),
      ],
    );
  }

  List<String> _readSelectedIds() {
    if (answer == null) {
      return const [];
    }

    final raw = answer?['user_answer'];
    if (raw is List) {
      return raw.map(_asText).where((value) => value.isNotEmpty).toList();
    }

    final fallback = answer?['drag_answers'];
    if (fallback is List) {
      return fallback.map(_asText).where((value) => value.isNotEmpty).toList();
    }

    return const [];
  }
}

class _DragDropAnswerBox extends StatelessWidget {
  const _DragDropAnswerBox({
    required this.title,
    required this.items,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String title;
  final List<String> items;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('-', style: TextStyle(color: Color(0xFF64748B)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(items.length, (index) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    '${index + 1}. ${items[index]}',
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
