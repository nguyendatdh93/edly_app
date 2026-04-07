import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/navigate.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:edupen/pages/quiz_detail/rooms/tsa_room/tsa_room_components.dart';
import 'package:flutter/material.dart';

class TsaRoomView extends StatefulWidget {
  const TsaRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<TsaRoomView> createState() => _TsaRoomViewState();
}

class _TsaRoomViewState extends State<TsaRoomView> {
  final QuizRoomAnswerState _answerState = QuizRoomAnswerState();
  Timer? _timer;

  late final List<QuizRoomModule> _modules;

  int _moduleIndex = 0;
  int _questionIndex = 0;
  int _moduleRemainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _isSubmitting = false;
  bool _startedModule = false;

  @override
  void initState() {
    super.initState();
    _modules = normalizeTopModules(widget.room);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  QuizRoomModule? get _currentModule {
    if (_modules.isEmpty) {
      return null;
    }
    return _modules[_moduleIndex.clamp(0, _modules.length - 1)];
  }

  List<QuizQuestion> get _currentQuestions {
    final module = _currentModule;
    if (module == null) {
      return const [];
    }
    return collectModuleQuestions(module);
  }

  int _moduleDurationSeconds(QuizRoomModule module) {
    if (module.minute > 0) {
      return module.minute * 60;
    }
    return 50 * 60;
  }

  void _startCurrentModule() {
    final module = _currentModule;
    if (module == null) {
      return;
    }

    _timer?.cancel();
    _moduleRemainingSeconds = _moduleDurationSeconds(module);
    _startedModule = true;

    if (_moduleRemainingSeconds <= 0) {
      setState(() {});
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isSubmitting) {
        return;
      }

      if (_moduleRemainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _moduleRemainingSeconds = 0;
          _elapsedSeconds += 1;
        });
        _submitCurrentModule(autoTriggered: true);
        return;
      }

      setState(() {
        _moduleRemainingSeconds -= 1;
        _elapsedSeconds += 1;
      });
    });

    setState(() {});
  }

  Future<void> _submitCurrentModule({bool autoTriggered = false}) async {
    if (_isSubmitting) {
      return;
    }

    if (_moduleIndex >= _modules.length - 1) {
      if (autoTriggered) {
        await _submitExam();
      } else {
        await _confirmSubmitExam();
      }
      return;
    }

    _timer?.cancel();
    setState(() {
      _moduleIndex += 1;
      _questionIndex = 0;
      _startedModule = false;
      _moduleRemainingSeconds = 0;
    });
  }

  void _nextQuestion() {
    final questions = _currentQuestions;
    if (questions.isEmpty) {
      _submitCurrentModule();
      return;
    }

    if (_questionIndex >= questions.length - 1) {
      _submitCurrentModule();
      return;
    }

    setState(() {
      _questionIndex += 1;
    });
  }

  void _previousQuestion() {
    if (_questionIndex <= 0) {
      return;
    }

    setState(() {
      _questionIndex -= 1;
    });
  }

  Future<void> _confirmSubmitExam() async {
    if (_isSubmitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài TSA'),
        content: const Text('Bạn chắc chắn muốn nộp toàn bộ bài thi TSA?'),
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

  Future<void> _submitExam() async {
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

    if (!success) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final module = _currentModule;
    final questions = _currentQuestions;

    if (module == null || questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng thi TSA')),
        body: const Center(child: Text('Đề thi TSA chưa có dữ liệu module.')),
      );
    }

    final safeQuestionIndex = _questionIndex.clamp(0, questions.length - 1);
    final currentQuestion = questions[safeQuestionIndex];
    final answered = _answerState.answeredCount(questions);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: !_startedModule
            ? TsaIntroCard(
                moduleName: module.name,
                minute: _moduleDurationSeconds(module) ~/ 60,
                moduleIndexText:
                    'Module ${_moduleIndex + 1}/${_modules.length}',
                onStart: _startCurrentModule,
              )
            : Column(
                children: [
                  TsaRoomHeader(
                    quizName: widget.room.quiz.name,
                    moduleName: module.name,
                    timerText: formatDuration(_moduleRemainingSeconds),
                    answeredText: '$answered/${questions.length}',
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: TsaRoomQuestionCard(
                              question: currentQuestion,
                              questionNumber: safeQuestionIndex + 1,
                              totalQuestions: questions.length,
                              answerState: _answerState,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: TsaRoomNavigate(
                            questions: questions,
                            currentIndex: safeQuestionIndex,
                            answerState: _answerState,
                            showMarked: false,
                            onTap: (index) {
                              setState(() {
                                _questionIndex = index;
                              });
                            },
                          ),
                        ),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: safeQuestionIndex > 0
                                    ? _previousQuestion
                                    : null,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Câu trước'),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _isSubmitting
                                      ? null
                                      : (safeQuestionIndex >=
                                                questions.length - 1
                                            ? _submitCurrentModule
                                            : _nextQuestion),
                                  icon: Icon(
                                    safeQuestionIndex >= questions.length - 1
                                        ? (_moduleIndex >= _modules.length - 1
                                              ? Icons.send_rounded
                                              : Icons.skip_next_rounded)
                                        : Icons.arrow_forward_rounded,
                                  ),
                                  label: Text(
                                    safeQuestionIndex >= questions.length - 1
                                        ? (_moduleIndex >= _modules.length - 1
                                              ? 'Nộp bài'
                                              : 'Module tiếp')
                                        : 'Câu tiếp',
                                  ),
                                ),
                              ),
                            ],
                          ),
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
