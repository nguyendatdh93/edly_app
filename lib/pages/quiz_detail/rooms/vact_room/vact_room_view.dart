import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/vact_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:edupen/pages/quiz_detail/rooms/vact_room/vact_room_components.dart';
import 'package:flutter/material.dart';

class VactRoomView extends StatefulWidget {
  const VactRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<VactRoomView> createState() => _VactRoomViewState();
}

class _VactRoomViewState extends State<VactRoomView> {
  final QuizRoomAnswerState _answerState = QuizRoomAnswerState();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  late final List<QuizRoomModule> _modules;

  int _remainingSeconds = 150 * 60;
  int _elapsedSeconds = 0;
  bool _isSubmitting = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _modules = normalizeTopModules(widget.room);

    final fallback = resolveRoomDurationSeconds(
      widget.room,
      fallbackMinutes: 150,
    );
    if (fallback > 0) {
      _remainingSeconds = fallback;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<QuizQuestion> get _allQuestions => collectQuestionsByModules(_modules);

  void _startExam() {
    if (_started) {
      return;
    }

    _started = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitting) {
        return;
      }

      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _elapsedSeconds += 1;
        });
        _submitExam(autoTriggered: true);
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
        _elapsedSeconds += 1;
      });
    });

    setState(() {});
  }

  Future<void> _confirmSubmit() async {
    if (_isSubmitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài V-ACT'),
        content: const Text('Bạn chắc chắn muốn nộp bài thi V-ACT?'),
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
      await _submitExam();
    }
  }

  Future<void> _submitExam({bool autoTriggered = false}) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await submitQuizRoom(
      context: context,
      room: widget.room,
      answers: _answerState,
      usedSeconds: _elapsedSeconds,
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

  @override
  Widget build(BuildContext context) {
    final moduleNames = _modules.map((item) => item.name).toList();
    final questions = _allQuestions;
    final answered = _answerState.answeredCount(questions);

    if (!_started) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: VactPreviewCard(
            quizName: widget.room.quiz.name,
            moduleNames: moduleNames,
            onStart: _startExam,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            VactRoomHeader(
              quizName: widget.room.quiz.name,
              timerText: formatDuration(_remainingSeconds),
              answeredText: '$answered/${questions.length}',
            ),
            Expanded(
              child: questions.isEmpty
                  ? const Center(
                      child: Text('Đề thi V-ACT chưa có câu hỏi để hiển thị.'),
                    )
                  : ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      children: [
                        for (
                          var moduleIndex = 0;
                          moduleIndex < _modules.length;
                          moduleIndex++
                        ) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                            child: Text(
                              _modules[moduleIndex].name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          for (final question in collectModuleQuestions(
                            _modules[moduleIndex],
                          ))
                            VactRoomQuestionCard(
                              question: question,
                              questionNumber: questions.indexOf(question) + 1,
                              totalQuestions: questions.length,
                              answerState: _answerState,
                              onChanged: () => setState(() {}),
                            ),
                        ],
                      ],
                    ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _confirmSubmit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Đang nộp bài...' : 'Nộp bài V-ACT',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
