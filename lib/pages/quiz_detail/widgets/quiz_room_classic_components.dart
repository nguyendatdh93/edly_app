import 'package:flutter/material.dart';

class ClassicQuestionNavItem {
  const ClassicQuestionNavItem({
    required this.label,
    required this.isCurrent,
    required this.isAnswered,
    required this.isBookmarked,
  });

  final int label;
  final bool isCurrent;
  final bool isAnswered;
  final bool isBookmarked;
}

class ClassicRoomLayout extends StatelessWidget {
  const ClassicRoomLayout({
    super.key,
    required this.candidateName,
    required this.candidateCode,
    required this.quizName,
    required this.examDate,
    required this.timerText,
    required this.timerDanger,
    required this.isSubmitting,
    required this.answeredCount,
    required this.totalQuestions,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onSubmit,
    required this.onPrevious,
    required this.onNext,
    required this.currentQuestionLabel,
    required this.isCurrentBookmarked,
    required this.onToggleBookmark,
    required this.scrollController,
    required this.questionContent,
    required this.answerInput,
    required this.navigatorItems,
    required this.onJumpToQuestion,
  });

  final String candidateName;
  final String candidateCode;
  final String quizName;
  final String examDate;
  final String timerText;
  final bool timerDanger;
  final bool isSubmitting;
  final int answeredCount;
  final int totalQuestions;
  final bool canGoPrevious;
  final bool canGoNext;
  final Future<void> Function() onSubmit;
  final VoidCallback? onPrevious;
  final Future<void> Function() onNext;
  final int currentQuestionLabel;
  final bool isCurrentBookmarked;
  final VoidCallback onToggleBookmark;
  final ScrollController scrollController;
  final Widget questionContent;
  final Widget answerInput;
  final List<ClassicQuestionNavItem> navigatorItems;
  final ValueChanged<int> onJumpToQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          ClassicRoomHeader(
            candidateName: candidateName,
            candidateCode: candidateCode,
            quizName: quizName,
            examDate: examDate,
            timerText: timerText,
            timerDanger: timerDanger,
            isSubmitting: isSubmitting,
            onSubmit: onSubmit,
          ),
          ClassicRoomActionBar(
            answeredCount: answeredCount,
            totalQuestions: totalQuestions,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            isSubmitting: isSubmitting,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: ClassicRoomQuestionCard(
                currentQuestionLabel: currentQuestionLabel,
                isBookmarked: isCurrentBookmarked,
                onToggleBookmark: onToggleBookmark,
                questionContent: questionContent,
                answerInput: answerInput,
              ),
            ),
          ),
          ClassicRoomNavigatorBar(
            items: navigatorItems,
            onJumpToQuestion: onJumpToQuestion,
          ),
        ],
      ),
    );
  }
}

class ClassicRoomHeader extends StatelessWidget {
  const ClassicRoomHeader({
    super.key,
    required this.candidateName,
    required this.candidateCode,
    required this.quizName,
    required this.examDate,
    required this.timerText,
    required this.timerDanger,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final String candidateName;
  final String candidateCode;
  final String quizName;
  final String examDate;
  final String timerText;
  final bool timerDanger;
  final bool isSubmitting;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B4DA1),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thí sinh: $candidateName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SBD: $candidateCode | Môn thi: $quizName | Ngày thi: $examDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE2ECFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: timerDanger
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF083A8A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  timerText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: FilledButton(
              onPressed: isSubmitting ? null : () => onSubmit(),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B4DA1),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'NỘP BÀI',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassicRoomActionBar extends StatelessWidget {
  const ClassicRoomActionBar({
    super.key,
    required this.answeredCount,
    required this.totalQuestions,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.isSubmitting,
    required this.onPrevious,
    required this.onNext,
  });

  final int answeredCount;
  final int totalQuestions;
  final bool canGoPrevious;
  final bool canGoNext;
  final bool isSubmitting;
  final VoidCallback? onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Đã làm: $answeredCount / $totalQuestions',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Quay lại'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: isSubmitting ? null : () => onNext(),
            icon: Icon(
              canGoNext ? Icons.arrow_forward_rounded : Icons.send_rounded,
              size: 16,
            ),
            label: Text(canGoNext ? 'Tiếp theo' : 'Nộp bài'),
          ),
        ],
      ),
    );
  }
}

class ClassicRoomQuestionCard extends StatelessWidget {
  const ClassicRoomQuestionCard({
    super.key,
    required this.currentQuestionLabel,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.questionContent,
    required this.answerInput,
  });

  final int currentQuestionLabel;
  final bool isBookmarked;
  final VoidCallback onToggleBookmark;
  final Widget questionContent;
  final Widget answerInput;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Câu $currentQuestionLabel',
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleBookmark,
                tooltip: 'Đánh dấu câu hỏi',
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          questionContent,
          const SizedBox(height: 12),
          answerInput,
        ],
      ),
    );
  }
}

class ClassicRoomNavigatorBar extends StatelessWidget {
  const ClassicRoomNavigatorBar({
    super.key,
    required this.items,
    required this.onJumpToQuestion,
  });

  final List<ClassicQuestionNavItem> items;
  final ValueChanged<int> onJumpToQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final style = _resolveItemStyle(item);
            return InkWell(
              onTap: () => onJumpToQuestion(index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: style.border),
                ),
                child: Text(
                  '${item.label}',
                  style: TextStyle(
                    color: style.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  _ClassicNavStyle _resolveItemStyle(ClassicQuestionNavItem item) {
    if (item.isBookmarked) {
      return const _ClassicNavStyle(
        background: Color(0xFFFED7AA),
        foreground: Color(0xFFEA580C),
        border: Color(0xFFF97316),
      );
    }
    if (item.isAnswered) {
      return const _ClassicNavStyle(
        background: Color(0xFFBFDBFE),
        foreground: Color(0xFF1D4ED8),
        border: Color(0xFF2563EB),
      );
    }
    if (item.isCurrent) {
      return const _ClassicNavStyle(
        background: Color(0xFF9CA3AF),
        foreground: Colors.white,
        border: Color(0xFFD1D5DB),
      );
    }
    return const _ClassicNavStyle(
      background: Color(0xFFE5E7EB),
      foreground: Color(0xFF374151),
      border: Color(0xFFE5E7EB),
    );
  }
}

class _ClassicNavStyle {
  const _ClassicNavStyle({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
