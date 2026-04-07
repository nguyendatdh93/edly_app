part of '../quiz_result_view.dart';

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({
    required this.indexedQuestion,
    required this.question,
    required this.answer,
    required this.isSelected,
    required this.isTranscriptOpen,
    required this.onToggleTranscript,
    required this.onTap,
  });

  final _IndexedQuestion indexedQuestion;
  final QuizQuestion question;
  final Map<String, dynamic>? answer;
  final bool isSelected;
  final bool isTranscriptOpen;
  final VoidCallback? onToggleTranscript;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answersMap = answer == null
        ? const <String, Map<String, dynamic>>{}
        : <String, Map<String, dynamic>>{question.id: answer!};
    final status = _statusOf(question, answersMap);
    final badge = _badgeForStatus(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A2563EB),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForStatus(status),
                            size: 18,
                            color: badge.foreground,
                          ),
                        ),
                        Text(
                          'Question ${indexedQuestion.displayNumber}',
                          style: const TextStyle(
                            color: QuizDetailPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badge.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge.label,
                            style: TextStyle(
                              color: badge.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      question.effectiveModuleName.isEmpty
                          ? 'Quiz'
                          : question.effectiveModuleName,
                      style: const TextStyle(
                        color: Color(0xFF324DC7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: _QuizContentView(
                  question: question,
                  raw: question.content.isNotEmpty
                      ? question.content
                      : question.title,
                  style: const TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                  maxImageHeight: 180,
                ),
              ),
              const SizedBox(height: 18),
              _ExamHistoryTypeView(question: question, answer: answer),
              const SizedBox(height: 16),
              _QuestionActionTabs(
                question: question,
                statusMessage: _statusMessageFor(status),
                isTranscriptOpen: isTranscriptOpen,
                onToggleTranscript: onToggleTranscript,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
