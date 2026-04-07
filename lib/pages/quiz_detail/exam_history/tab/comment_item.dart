part of '../../quiz_result_view.dart';

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.onReply,
    this.depth = 0,
  });

  final _ExamCommentNode comment;
  final ValueChanged<String> onReply;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final isTeacher = comment.userRole.toLowerCase() == 'teacher';
    final marginLeft = (depth * 18).toDouble();

    return Container(
      margin: EdgeInsets.only(left: marginLeft),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: QuizDetailPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (isTeacher) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'GV',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                comment.createdAt,
                style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.content,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => onReply(comment.id),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Trả lời',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...comment.replies.map(
              (reply) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _CommentItem(
                  comment: reply,
                  onReply: onReply,
                  depth: depth + 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
