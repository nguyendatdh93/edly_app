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
            height: compact ? 24 : 26,
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
    required this.currentQuestionNumber,
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

  final int currentQuestionNumber;
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
    final baseHeight = compact ? 20.0 : 22.0;
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
            'Câu $currentQuestionNumber • Đã làm: $answeredCount/$totalQuestions',
            style: TextStyle(
              color: const Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: textSize,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: isCurrentBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: 'Đánh dấu',
                      onTap: onBookmark,
                      selected: isCurrentBookmarked,
                      selectedBackgroundColor: const Color(0xFFFFEDD5),
                      selectedBorderColor: const Color(0xFFFB923C),
                      selectedForegroundColor: const Color(0xFFC2410C),
                      height: baseHeight,
                      compact: compact,
                    ),
                    SizedBox(width: tinyGap),
                    _MiniActionButton(
                      icon: isTimerVisible
                          ? Icons.timer_off_rounded
                          : Icons.timer_rounded,
                      label: 'Thời gian',
                      onTap: onToggleTimer,
                      selected: isTimerVisible,
                      height: baseHeight,
                      compact: compact,
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

class DefaultRoomSideNavigationButton extends StatelessWidget {
  const DefaultRoomSideNavigationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.trailingIcon = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool trailingIcon;

  @override
  Widget build(BuildContext context) {
    final baseBgColor = primary
        ? const Color(0xFF4F46E5)
        : const Color(0xFF0F172A);
    final baseFgColor = Colors.white;

    Color faded(Color color, double opacity) =>
        color.withValues(alpha: opacity.clamp(0.0, 1.0));

    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: trailingIcon
          ? [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18),
            ]
          : [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
    );

    return OutlinedButton(
      onPressed: onTap,
      child: buttonChild,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ).copyWith(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return faded(baseFgColor, 0.45);
          }
          if (states.contains(WidgetState.pressed)) {
            return baseFgColor;
          }
          return faded(baseFgColor, 0.92);
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return faded(baseBgColor, 0.2);
          }
          if (states.contains(WidgetState.pressed)) {
            return baseBgColor;
          }
          return faded(baseBgColor, 0.2);
        }),
        side: const WidgetStatePropertyAll(BorderSide.none),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.white.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
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
    this.selectedBackgroundColor,
    this.selectedBorderColor,
    this.selectedForegroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final double height;
  final bool compact;
  final bool primary;
  final bool selected;
  final Color? selectedBackgroundColor;
  final Color? selectedBorderColor;
  final Color? selectedForegroundColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = primary
        ? const Color(0xFF4F46E5)
        : selected
            ? (selectedBackgroundColor ?? const Color(0xFFE0E7FF))
            : Colors.white;
    final borderColor = primary
        ? const Color(0xFF4F46E5)
        : selected
            ? (selectedBorderColor ?? const Color(0xFF818CF8))
            : const Color(0xFFCBD5E1);
    final fgColor = primary
        ? Colors.white
        : selected
            ? (selectedForegroundColor ?? const Color(0xFF3730A3))
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
