import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/default_room_components.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/navigate.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _questions = widget.room.questions;
    _totalSeconds = resolveRoomDurationSeconds(widget.room);
    _remainingSeconds = _totalSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
  }

  void _goPrevious() {
    if (_currentIndex <= 0) {
      return;
    }
    setState(() {
      _currentIndex -= 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final answered = _answerState.answeredCount(_questions);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            DefaultRoomHeader(
              title: widget.room.quiz.name,
              timerText: formatDuration(_remainingSeconds),
              answeredText: '$answered/${_questions.length}',
            ),
            if (question == null)
              const Expanded(
                child: Center(child: Text('Đề thi chưa có câu hỏi.')),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: DefaultRoomQuestionCard(
                          question: question,
                          questionNumber: _currentIndex + 1,
                          totalQuestions: _questions.length,
                          answerState: _answerState,
                          onChanged: () => setState(() {}),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: DefaultRoomNavigate(
                        questions: _questions,
                        currentIndex: _currentIndex,
                        answerState: _answerState,
                        onTap: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                      ),
                    ),
                    DefaultRoomFooter(
                      onPrevious: _goPrevious,
                      onNext: _goNext,
                      onSubmit: _confirmSubmit,
                      canPrevious: _currentIndex > 0,
                      isLastQuestion: _currentIndex >= _questions.length - 1,
                      isSubmitting: _isSubmitting,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
