part of '../../quiz_result_view.dart';

class _SolutionTab extends StatelessWidget {
  const _SolutionTab({
    super.key,
    required this.question,
    required this.statusMessage,
    required this.isTranscriptOpen,
    required this.onToggleTranscript,
  });

  final QuizQuestion question;
  final _StatusMessagePresentation statusMessage;
  final bool isTranscriptOpen;
  final VoidCallback? onToggleTranscript;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusMessage.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusMessage.border),
          ),
          child: Text(
            statusMessage.text,
            style: TextStyle(
              color: statusMessage.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (question.explanation.trim().isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Chưa có lời giải cho câu này.',
              style: TextStyle(
                color: QuizDetailPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8DFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lời giải chi tiết',
                  style: TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _QuizContentView(
                  question: question,
                  raw: question.explanation,
                  style: const TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                  maxImageHeight: 150,
                ),
                if (_hasTranscript(question)) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: onToggleTranscript,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTranscriptOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Transcript',
                          style: TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isTranscriptOpen) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: _QuizContentView(
                        question: question,
                        raw: question.transcript,
                        style: const TextStyle(
                          color: QuizDetailPalette.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        maxImageHeight: 120,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
      ],
    );
  }
}
