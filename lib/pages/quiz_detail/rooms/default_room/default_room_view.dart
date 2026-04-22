import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/default_room_components.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/navigate.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class DefaultRoomView extends StatefulWidget {
  const DefaultRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<DefaultRoomView> createState() => _DefaultRoomViewState();
}

class _DefaultRoomViewState extends State<DefaultRoomView> {
  final QuizRoomAnswerState _answerState = QuizRoomAnswerState();
  Timer? _timer;

  late final List<QuizQuestion> _questions;
  late final int _totalSeconds;

  int _remainingSeconds = 0;
  int _currentIndex = 0;
  bool _isSubmitting = false;
  bool _showTimer = true;

  @override
  void initState() {
    super.initState();
    _questions = widget.room.questions;
    _totalSeconds = resolveRoomDurationSeconds(widget.room);
    _remainingSeconds = _totalSeconds;
    _startTimer();
    unawaited(_lockLandscapeOrientation());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_unlockPortraitOrientation());
    super.dispose();
  }

  Future<void> _lockLandscapeOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _unlockPortraitOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _startTimer() {
    if (_totalSeconds <= 0) {
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitting) {
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        _submit(autoTriggered: true);
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
      });
    });
  }

  QuizQuestion? get _currentQuestion {
    if (_questions.isEmpty) {
      return null;
    }
    final safeIndex = _currentIndex.clamp(0, _questions.length - 1);
    return _questions[safeIndex];
  }

  Future<void> _submit({bool autoTriggered = false}) async {
    if (_isSubmitting || _questions.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final usedSeconds = _totalSeconds > 0
        ? (_totalSeconds - _remainingSeconds).clamp(0, _totalSeconds)
        : 0;

    final success = await submitQuizRoom(
      context: context,
      room: widget.room,
      answers: _answerState,
      usedSeconds: usedSeconds,
    );

    if (!mounted) {
      return;
    }

    if (!success && autoTriggered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hết giờ, vui lòng thử nộp bài lại.')),
      );
    }

    if (!success) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài thi'),
        content: const Text('Bạn có chắc chắn muốn nộp bài?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _submit();
    }
  }

  void _goNext() {
    if (_currentIndex >= _questions.length - 1) {
      _confirmSubmit();
      return;
    }
    setState(() {
      _currentIndex += 1;
    });
    _scrollToTop();
  }

  void _goPrevious() {
    if (_currentIndex <= 0) {
      return;
    }
    setState(() {
      _currentIndex -= 1;
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    // Nội dung trong card đã có vùng cuộn riêng nên không cần cuộn trang ngoài.
  }

  void _toggleCurrentBookmark() {
    final current = _currentQuestion;
    if (current == null) {
      return;
    }
    _answerState.toggleMarked(current.id);
    setState(() {});
  }

  void _toggleTimerVisibility() {
    setState(() {
      _showTimer = !_showTimer;
    });
  }

  void _showDirections() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Directions'),
        content: const Text(
          'Đọc kỹ nội dung câu hỏi ở cột trái, chọn hoặc nhập đáp án ở cột phải, sau đó bấm Next để sang câu tiếp theo.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showCalculator() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calculator sẽ được tích hợp chi tiết ở bản tiếp theo.'),
      ),
    );
  }

  void _showReference() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reference'),
        content: const Text(
          'Bạn có thể bật bảng công thức/reference ở phiên bản tiếp theo. Hiện tại câu hỏi vẫn hiển thị đầy đủ nội dung cần thiết.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showQuestionBoardHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question Board nằm ở thanh số câu phía dưới màn hình.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final answered = _answerState.answeredCount(_questions);
    final screenSize = MediaQuery.sizeOf(context);
    final compactTopBar = screenSize.height < 440 || screenSize.width < 760;
    final user = AuthRepository.instance.currentUser;
    final candidateName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Thí sinh';
    final candidateCode = (user?.id ?? 0) > 0 ? '${user!.id}' : '-';
    final timerDanger = _remainingSeconds > 0 && _remainingSeconds <= 5 * 60;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            DefaultRoomHeader(
              candidateName: candidateName,
              candidateCode: candidateCode,
              quizName: widget.room.quiz.name,
              examDate: DateFormat('dd/MM/yyyy').format(DateTime.now()),
              timerText: formatDuration(_remainingSeconds),
              timerDanger: timerDanger,
              showTimer: _showTimer,
              isSubmitting: _isSubmitting,
              onSubmit: _confirmSubmit,
              compact: compactTopBar,
            ),
            DefaultRoomActionBar(
              currentQuestionNumber: _currentIndex + 1,
              answeredCount: answered,
              totalQuestions: _questions.length,
              onPrevious: _goPrevious,
              onNext: _goNext,
              canPrevious: _currentIndex > 0,
              canNext: _currentIndex < _questions.length - 1,
              isSubmitting: _isSubmitting,
              onDirections: _showDirections,
              onCalculator: _showCalculator,
              onReference: _showReference,
              onQuestionBoard: _showQuestionBoardHint,
              onBookmark: _toggleCurrentBookmark,
              onToggleTimer: _toggleTimerVisibility,
              isCurrentBookmarked:
                  question != null && _answerState.isMarked(question.id),
              isTimerVisible: _showTimer,
              compact: compactTopBar,
            ),
            if (question == null)
              const Expanded(
                child: Center(child: Text('Đề thi chưa có câu hỏi.')),
              )
            else
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: DefaultRoomQuestionCard(
                          question: question,
                          questionNumber: _currentIndex + 1,
                          totalQuestions: _questions.length,
                          answerState: _answerState,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: DefaultRoomSideNavigationButton(
                          label: 'Trước',
                          icon: Icons.arrow_back_rounded,
                          onTap: _currentIndex <= 0 ? null : _goPrevious,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: DefaultRoomSideNavigationButton(
                          icon: Icons.arrow_forward_rounded,
                          label: 'Sau',
                          onTap: _isSubmitting || _currentIndex >= _questions.length - 1
                              ? null
                              : _goNext,
                          primary: true,
                          trailingIcon: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: DefaultRoomNavigate(
                questions: _questions,
                currentIndex: _currentIndex,
                answerState: _answerState,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  _scrollToTop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
