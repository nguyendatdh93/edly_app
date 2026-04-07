import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/literature_room_components.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:flutter/material.dart';

class LiteratureRoomView extends StatefulWidget {
  const LiteratureRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<LiteratureRoomView> createState() => _LiteratureRoomViewState();
}

class _LiteratureRoomViewState extends State<LiteratureRoomView> {
  final QuizRoomAnswerState _answerState = QuizRoomAnswerState();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  late final List<QuizQuestion> _questions;
  late final int _totalSeconds;

  int _remainingSeconds = 0;
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
    _scrollController.dispose();
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
        const SnackBar(content: Text('Hết giờ, vui lòng nộp lại.')),
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
        title: const Text('Nộp bài thi Ngữ văn'),
        content: const Text('Bạn có muốn nộp bài ngay lúc này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tiếp tục làm'),
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

  @override
  Widget build(BuildContext context) {
    final answered = _answerState.answeredCount(_questions);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            LiteratureRoomHeader(
              title: widget.room.quiz.name,
              timer: formatDuration(_remainingSeconds),
              answered: '$answered/${_questions.length}',
            ),
            Expanded(
              child: _questions.isEmpty
                  ? const Center(child: Text('Đề văn này chưa có câu hỏi.'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        return LiteratureRoomQuestionCard(
                          question: _questions[index],
                          questionNumber: index + 1,
                          totalQuestions: _questions.length,
                          answerState: _answerState,
                          onChanged: () => setState(() {}),
                        );
                      },
                    ),
            ),
            LiteratureSubmitBar(
              onSubmit: _confirmSubmit,
              isSubmitting: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}
