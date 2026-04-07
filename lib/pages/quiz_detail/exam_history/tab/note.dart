part of '../../quiz_result_view.dart';

class _NoteTab extends StatefulWidget {
  const _NoteTab({super.key, required this.questionId});

  final String questionId;

  @override
  State<_NoteTab> createState() => _NoteTabState();
}

class _NoteTabState extends State<_NoteTab> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _saving = false;
  bool _focused = false;
  DateTime? _lastSavedAt;
  String _lastSavedContent = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onContentChanged);
    _loadNote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() {
      _loading = true;
    });

    try {
      final content = await QuizDetailRepository.instance.fetchQuestionNote(
        widget.questionId,
      );

      if (!mounted) {
        return;
      }

      _controller.text = content;
      _lastSavedContent = content;

      setState(() {
        _loading = false;
        if (content.trim().isNotEmpty) {
          _lastSavedAt = DateTime.now();
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không tải được ghi chú.')));
    }
  }

  void _onContentChanged() {
    final text = _controller.text;
    if (_loading || text == _lastSavedContent) {
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _saveNote);
  }

  Future<void> _saveNote() async {
    if (_saving || !mounted) {
      return;
    }

    final text = _controller.text;
    if (text == _lastSavedContent) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await QuizDetailRepository.instance.saveQuestionNote(
        questionId: widget.questionId,
        content: text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
        _lastSavedAt = DateTime.now();
        _lastSavedContent = text;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lưu ghi chú thất bại, vui lòng thử lại.'),
        ),
      );
    }
  }

  String _formatLastSaved() {
    final time = _lastSavedAt;
    if (time == null) {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 10) {
      return 'vừa xong';
    }
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} giây trước';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }

    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

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
              color: Color(0xFFFFFBEB),
              border: Border(bottom: BorderSide(color: Color(0xFFFDE68A))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.note_alt_outlined,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ghi chú cá nhân',
                    style: TextStyle(
                      color: QuizDetailPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_saving)
                  const Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đang lưu...',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else if (_lastSavedAt != null)
                  Text(
                    'Đã lưu ${_formatLastSaved()}',
                    style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  minLines: _focused ? 6 : 4,
                  maxLines: _focused ? 6 : 4,
                  onTap: () {
                    if (!_focused) {
                      setState(() {
                        _focused = true;
                      });
                    }
                  },
                  onTapOutside: (_) {
                    if (_focused) {
                      setState(() {
                        _focused = false;
                      });
                    }
                    FocusScope.of(context).unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Viết ghi chú riêng cho câu hỏi này...',
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
                Text(
                  'Chỉ bạn có thể xem nội dung này · Tự động lưu sau mỗi thay đổi.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
