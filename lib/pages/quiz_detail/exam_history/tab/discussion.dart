part of '../../quiz_result_view.dart';

class _DiscussionTab extends StatefulWidget {
  const _DiscussionTab({super.key, required this.questionId});

  final String questionId;

  @override
  State<_DiscussionTab> createState() => _DiscussionTabState();
}

class _DiscussionTabState extends State<_DiscussionTab> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<_ExamCommentNode> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _replyingTo;

  int get _commentCount =>
      _comments.fold<int>(0, (sum, item) => sum + item.totalCount);

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _loading = true;
    });

    try {
      final data = await QuizDetailRepository.instance.fetchQuestionComments(
        widget.questionId,
      );
      final rows = data.map(_ExamCommentNode.fromJson).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _comments = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được thảo luận.')),
      );
    }
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await QuizDetailRepository.instance.saveQuestionComment(
        questionId: widget.questionId,
        content: content,
        parentId: _replyingTo,
      );

      if (!mounted) {
        return;
      }

      _controller.clear();
      _focusNode.unfocus();

      setState(() {
        _sending = false;
        _replyingTo = null;
      });

      await _fetchComments();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã gửi bình luận.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gửi bình luận thất bại, vui lòng thử lại.'),
        ),
      );
    }
  }

  void _setReply(String id) {
    setState(() {
      _replyingTo = id;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: Color(0xFF1D4ED8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _commentCount > 0
                        ? 'Thảo luận ($_commentCount bình luận)'
                        : 'Thảo luận',
                    style: const TextStyle(
                      color: QuizDetailPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _fetchComments,
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          color: Color(0xFF1D4ED8),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Đang trả lời bình luận',
                            style: TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _cancelReply,
                          child: const Text('Hủy'),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (_) => setState(() {}),
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Chia sẻ câu hỏi hoặc thắc mắc của bạn...',
                    hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF60A5FA)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hãy lịch sự và tôn trọng trong giao tiếp.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _sending || _controller.text.trim().isEmpty
                          ? null
                          : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: Text(_sending ? 'Đang gửi...' : 'Gửi bình luận'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_comments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Chưa có bình luận nào',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _comments
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CommentItem(
                              comment: item,
                              onReply: _setReply,
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCommentNode {
  const _ExamCommentNode({
    required this.id,
    required this.content,
    required this.parentId,
    required this.userName,
    required this.userRole,
    required this.createdAt,
    required this.replies,
  });

  final String id;
  final String content;
  final String? parentId;
  final String userName;
  final String userRole;
  final String createdAt;
  final List<_ExamCommentNode> replies;

  int get totalCount =>
      1 + replies.fold<int>(0, (sum, item) => sum + item.totalCount);

  factory _ExamCommentNode.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] is Map)
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    final rawReplies = json['replies'];

    return _ExamCommentNode(
      id: _asText(json['id']),
      content: _asText(json['content']),
      parentId: _asText(json['parent_id']).isEmpty
          ? null
          : _asText(json['parent_id']),
      userName: _asText(user['name']).isEmpty
          ? 'Ẩn danh'
          : _asText(user['name']),
      userRole: _asText(user['role']),
      createdAt: _asText(json['created_at']),
      replies: rawReplies is List
          ? rawReplies
                .whereType<Map>()
                .map(
                  (item) => _ExamCommentNode.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}
