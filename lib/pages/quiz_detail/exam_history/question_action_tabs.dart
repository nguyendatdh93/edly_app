part of '../quiz_result_view.dart';

class _QuestionActionTabs extends StatefulWidget {
  const _QuestionActionTabs({
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
  State<_QuestionActionTabs> createState() => _QuestionActionTabsState();
}

class _QuestionActionTabsState extends State<_QuestionActionTabs> {
  _QuestionActionTab _activeTab = _QuestionActionTab.solution;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                _ActionTabButton(
                  label: 'Xem lời giải',
                  selected: _activeTab == _QuestionActionTab.solution,
                  onTap: () => setState(() {
                    _activeTab = _QuestionActionTab.solution;
                  }),
                ),
                const SizedBox(width: 8),
                _ActionTabButton(
                  label: 'Hỏi đáp / Thảo luận',
                  selected: _activeTab == _QuestionActionTab.discussion,
                  onTap: () => setState(() {
                    _activeTab = _QuestionActionTab.discussion;
                  }),
                ),
                const SizedBox(width: 8),
                _ActionTabButton(
                  label: 'Ghi chú',
                  selected: _activeTab == _QuestionActionTab.note,
                  onTap: () => setState(() {
                    _activeTab = _QuestionActionTab.note;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_activeTab) {
                _QuestionActionTab.discussion => _DiscussionTab(
                  key: const ValueKey<String>('discussion'),
                  questionId: widget.question.id,
                ),
                _QuestionActionTab.note => _NoteTab(
                  key: const ValueKey<String>('note'),
                  questionId: widget.question.id,
                ),
                _QuestionActionTab.solution => _SolutionTab(
                  key: const ValueKey<String>('solution'),
                  question: widget.question,
                  statusMessage: widget.statusMessage,
                  isTranscriptOpen: widget.isTranscriptOpen,
                  onToggleTranscript: widget.onToggleTranscript,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _QuestionActionTab { solution, discussion, note }

class _ActionTabButton extends StatelessWidget {
  const _ActionTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D4ED8) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF1D4ED8) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF475467),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
