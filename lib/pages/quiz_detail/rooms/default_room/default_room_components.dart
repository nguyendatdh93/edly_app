import 'package:edupen/pages/quiz_detail/rooms/default_room/time.dart';
import 'package:flutter/material.dart';

class DefaultRoomHeader extends StatelessWidget {
  const DefaultRoomHeader({
    super.key,
    required this.candidateName,
    required this.candidateCode,
    required this.quizName,
    required this.examDate,
    required this.timerText,
    required this.timerDanger,
    required this.showTimer,
    required this.isSubmitting,
    required this.onSubmit,
    this.compact = false,
  });

  final String candidateName;
  final String candidateCode;
  final String quizName;
  final String examDate;
  final String timerText;
  final bool timerDanger;
  final bool showTimer;
  final bool isSubmitting;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 12.0 : 13.0;
    final subtitleSize = compact ? 10.0 : 11.0;

    return Container(
      color: const Color(0xFF0B4DA1),
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 4 : 6,
        compact ? 8 : 10,
        compact ? 4 : 6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thí sinh: $candidateName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: titleSize,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'SBD: $candidateCode | Môn thi: $quizName | Ngày thi: $examDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFE2ECFF),
                    fontSize: subtitleSize,
                  ),
                ),
              ],
            ),
          ),
          if (showTimer) ...[
            SizedBox(width: compact ? 4 : 6),
            DefaultRoomTime(
              value: timerText,
              compact: true,
              highlight: timerDanger,
            ),
          ],
          SizedBox(width: compact ? 4 : 6),
          SizedBox(
            height: compact ? 30 : 32,
            child: FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0B4DA1),
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: compact ? 12 : 14,
                      height: compact ? 12 : 14,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'NỘP BÀI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 11 : 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class DefaultRoomActionBar extends StatelessWidget {
  const DefaultRoomActionBar({
    super.key,
    required this.answeredCount,
    required this.totalQuestions,
    required this.onPrevious,
    required this.onNext,
    required this.canPrevious,
    required this.canNext,
    required this.isSubmitting,
    required this.onDirections,
    required this.onCalculator,
    required this.onReference,
    required this.onQuestionBoard,
    required this.onBookmark,
    required this.onToggleTimer,
    required this.isCurrentBookmarked,
    required this.isTimerVisible,
    this.compact = false,
  });

  final int answeredCount;
  final int totalQuestions;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final bool canPrevious;
  final bool canNext;
  final bool isSubmitting;
  final VoidCallback onDirections;
  final VoidCallback onCalculator;
  final VoidCallback onReference;
  final VoidCallback onQuestionBoard;
  final VoidCallback onBookmark;
  final VoidCallback onToggleTimer;
  final bool isCurrentBookmarked;
  final bool isTimerVisible;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseHeight = compact ? 30.0 : 34.0;
    final textSize = compact ? 11.0 : 12.0;
    final tinyGap = compact ? 4.0 : 6.0;

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 10,
        compact ? 3 : 4,
        compact ? 8 : 10,
        compact ? 3 : 4,
      ),
      child: Row(
        children: [
          Text(
            'Đã làm: $answeredCount / $totalQuestions',
            style: TextStyle(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: textSize,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MiniActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Directions',
                      onTap: onDirections,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: Icons.calculate_rounded,
                      label: 'Calculator',
                      onTap: onCalculator,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: Icons.library_books_rounded,
                      label: 'Reference',
                      onTap: onReference,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: Icons.grid_view_rounded,
                      label: 'Question Board',
                      onTap: onQuestionBoard,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: isCurrentBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: 'Bookmark',
                      onTap: onBookmark,
                      selected: isCurrentBookmarked,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: isTimerVisible
                          ? Icons.timer_off_rounded
                          : Icons.timer_rounded,
                      label: 'Timer',
                      onTap: onToggleTimer,
                      selected: isTimerVisible,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Back',
                      onTap: canPrevious ? onPrevious : null,
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: canNext
                          ? Icons.arrow_forward_rounded
                          : Icons.send_rounded,
                      label: canNext ? 'Next' : 'Submit',
                      onTap: isSubmitting ? null : onNext,
                      height: baseHeight,
                      compact: compact,
                      primary: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.height,
    required this.compact,
    this.primary = false,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool compact;
  final bool primary;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = primary
        ? const Color(0xFF4F46E5)
        : selected
        ? const Color(0xFFE0E7FF)
        : Colors.white;
    final borderColor = primary
        ? const Color(0xFF4F46E5)
        : selected
        ? const Color(0xFF818CF8)
        : const Color(0xFFCBD5E1);
    final fgColor = primary
        ? Colors.white
        : selected
        ? const Color(0xFF3730A3)
        : const Color(0xFF334155);

    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: compact ? 14 : 15, color: fgColor),
        label: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: bgColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 0,
          ),
        ),
      ),
    );
  }
}
