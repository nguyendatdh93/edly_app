import 'dart:async';

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/hsa_room/hsa_room_components.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/hsa_room/question.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_submitter.dart';
import 'package:flutter/material.dart';

class HsaRoomView extends StatefulWidget {
  const HsaRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<HsaRoomView> createState() => _HsaRoomViewState();
}

class _HsaRoomViewState extends State<HsaRoomView> {
  final QuizRoomAnswerState _answerState = QuizRoomAnswerState();
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  late final List<QuizRoomModule> _modules;

  int _moduleIndex = 0;
  int _moduleRemainingSeconds = 0;
  int _elapsedSeconds = 0;
  bool _isSubmitting = false;
  String _step = 'preview'; // preview | intro | exam
  Set<String> _selectedPart3Subjects = <String>{};

  @override
  void initState() {
    super.initState();
    _modules = normalizeTopModules(widget.room);
    _bootstrapPart3Selection();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  QuizRoomModule? get _currentModule {
    if (_modules.isEmpty) {
      return null;
    }
    return _modules[_moduleIndex.clamp(0, _modules.length - 1)];
  }

  bool _isPart3Module(int index) => index == 2;

  List<String> get _part3Subjects {
    if (_modules.length <= 2) {
      return const [];
    }
    return _modules[2].children
        .map((item) => item.name.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _bootstrapPart3Selection() {
    final subjects = _part3Subjects;
    if (subjects.isEmpty) {
      _selectedPart3Subjects = <String>{};
      return;
    }

    if (subjects.contains('Tiếng Anh')) {
      _selectedPart3Subjects = {'Tiếng Anh'};
      return;
    }

    final seed = subjects.take(3).toSet();
    _selectedPart3Subjects = seed.isEmpty ? subjects.toSet() : seed;
  }

  void _togglePart3Subject(String subject) {
    setState(() {
      final selected = {..._selectedPart3Subjects};
      if (selected.contains(subject)) {
        selected.remove(subject);
      } else {
        if (subject == 'Tiếng Anh') {
          selected
            ..clear()
            ..add(subject);
        } else {
          selected.remove('Tiếng Anh');
          if (selected.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bạn chỉ có thể chọn tối đa 3 môn cho phần này.'),
              ),
            );
            return;
          }
          selected.add(subject);
        }
      }

      if (selected.isEmpty) {
        selected.add(subject);
      }

      _selectedPart3Subjects = selected;
    });
  }

  int _moduleDurationSeconds(QuizRoomModule module) {
    if (module.minute > 0) {
      return module.minute * 60;
    }
    return 50 * 60;
  }

  List<QuizQuestion> _moduleQuestionsForIndex(int index) {
    if (_modules.isEmpty || index < 0 || index >= _modules.length) {
      return const [];
    }

    final module = _modules[index];
    if (!_isPart3Module(index)) {
      return collectModuleQuestions(module);
    }

    if (module.children.isEmpty) {
      return collectModuleQuestions(module).take(50).toList();
    }

    final selectedSubjects = _selectedPart3Subjects.isEmpty
        ? _part3Subjects.toSet()
        : _selectedPart3Subjects;

    final picked = module.children.where(
      (item) => selectedSubjects.contains(item.name),
    );

    final rows = collectQuestionsByModules(picked.toList());
    if (rows.length <= 50) {
      return rows;
    }
    return rows.take(50).toList();
  }

  List<QuizQuestion> get _currentQuestions =>
      _moduleQuestionsForIndex(_moduleIndex);

  List<String> _selectedQuestionIdsForSubmit() {
    final ids = <String>[];
    for (var index = 0; index < _modules.length; index++) {
      for (final question in _moduleQuestionsForIndex(index)) {
        if (question.id.isEmpty || ids.contains(question.id)) {
          continue;
        }
        ids.add(question.id);
      }
    }
    return ids;
  }

  void _startCurrentModule() {
    final module = _currentModule;
    if (module == null) {
      return;
    }

    _timer?.cancel();
    _moduleRemainingSeconds = _moduleDurationSeconds(module);
    _step = 'exam';

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
      _step = 'intro';
      _moduleRemainingSeconds = 0;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _confirmSubmitExam() async {
    if (_isSubmitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nộp bài HSA'),
        content: const Text('Bạn chắc chắn muốn nộp toàn bộ bài thi HSA?'),
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
      questionIdsOverride: _selectedQuestionIdsForSubmit(),
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
    if (module == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng thi HSA')),
        body: const Center(child: Text('Đề thi HSA chưa có dữ liệu module.')),
      );
    }

    final moduleNames = _modules.map((item) => item.name).toList();
    final questions = _currentQuestions;
    final answered = _answerState.answeredCount(questions);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: switch (_step) {
          'preview' => HsaPreviewCard(
            quizName: widget.room.quiz.name,
            moduleNames: moduleNames,
            part3Subjects: _part3Subjects,
            selectedSubjects: _selectedPart3Subjects,
            onToggleSubject: _togglePart3Subject,
            onStart: () {
              setState(() {
                _step = 'intro';
              });
            },
          ),
          'intro' => HsaIntroCard(
            moduleName: module.name,
            minute: _moduleDurationSeconds(module) ~/ 60,
            moduleIndexText: 'Module ${_moduleIndex + 1}/${_modules.length}',
            onStart: _startCurrentModule,
          ),
          _ => Column(
            children: [
              HsaRoomHeader(
                quizName: widget.room.quiz.name,
                moduleName: module.name,
                timerText: formatDuration(_moduleRemainingSeconds),
                answeredText: '$answered/${questions.length}',
              ),
              Expanded(
                child: questions.isEmpty
                    ? const Center(
                        child: Text('Module này chưa có câu hỏi để hiển thị.'),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        itemCount: questions.length,
                        itemBuilder: (context, index) {
                          return HsaRoomQuestionCard(
                            question: questions[index],
                            questionNumber: index + 1,
                            totalQuestions: questions.length,
                            answerState: _answerState,
                            onChanged: () => setState(() {}),
                          );
                        },
                      ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _moduleIndex > 0
                          ? () {
                              _timer?.cancel();
                              setState(() {
                                _moduleIndex -= 1;
                                _step = 'intro';
                              });
                            }
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Module trước'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : (_moduleIndex >= _modules.length - 1
                                  ? _confirmSubmitExam
                                  : _submitCurrentModule),
                        icon: Icon(
                          _moduleIndex >= _modules.length - 1
                              ? Icons.send_rounded
                              : Icons.skip_next_rounded,
                        ),
                        label: Text(
                          _moduleIndex >= _modules.length - 1
                              ? 'Nộp bài'
                              : 'Module tiếp',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}
