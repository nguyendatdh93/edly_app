import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edly/pages/quiz_detail/quiz_congratulations_view.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xml/xml.dart' as xml;

class QuizRoomView extends StatefulWidget {
  const QuizRoomView({super.key, required this.room});

  final QuizRoomData room;

  @override
  State<QuizRoomView> createState() => _QuizRoomViewState();
}

class _QuizRoomViewState extends State<QuizRoomView> {
  static const List<String> _moduleOrder = [
    'Module I: Reading and Writing',
    'Module II: Reading and Writing',
    'Module I: Math',
    'Module II: Math',
  ];

  static const Map<String, String> _moduleKeyMap = {
    'Module I: Reading and Writing': 'rw1',
    'Module II: Reading and Writing': 'rw2',
    'Module I: Math': 'm1',
    'Module II: Math': 'm2',
  };

  final Map<String, String> _selectedOptions = {};
  final Map<String, String> _textAnswers = {};
  final Map<String, bool> _markedForReview = {};
  final Map<String, bool> _exerciseChecked = {};
  final Map<String, int?> _moduleTimes = {
    'rw1': null,
    'rw2': null,
    'm1': null,
    'm2': null,
    'module_custom': null,
  };

  late final List<_RoomModuleBlock> _modules;
  int _activeModuleIndex = 0;
  int _currentQuestionIndex = 0;
  bool _isSubmitting = false;
  bool _showLoadingScreen = false;
  bool _showModuleReview = false;
  bool _timerVisible = true;
  int? _remainingSeconds;
  Timer? _timer;
  int? _breakRemainingSeconds;
  Timer? _breakTimer;

  @override
  void initState() {
    super.initState();
    _modules = _buildModules(widget.room);
    _lockLandscape();
    _setupTimerForActiveModule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _breakTimer?.cancel();
    _unlockOrientation();
    super.dispose();
  }

  Future<void> _lockLandscape() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _unlockOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  _RoomModuleBlock? get _activeModule {
    if (_modules.isEmpty || _activeModuleIndex >= _modules.length) {
      return null;
    }
    return _modules[_activeModuleIndex];
  }

  List<QuizQuestion> get _activeQuestions {
    return _activeModule?.questions ?? const [];
  }

  List<_RoomModuleBlock> _buildModules(QuizRoomData room) {
    final grouped = <String, List<QuizQuestion>>{};
    for (final question in room.questions) {
      final moduleName = question.module.trim().isEmpty
          ? 'Quiz'
          : question.module.trim();
      grouped.putIfAbsent(moduleName, () => <QuizQuestion>[]).add(question);
    }

    if (grouped.isEmpty) {
      return const [];
    }

    final orderedNames = <String>[];
    final hasClassicOrder = _moduleOrder.every(grouped.containsKey);
    if (hasClassicOrder) {
      orderedNames.addAll(_moduleOrder);
    }
    for (final name in grouped.keys) {
      if (!orderedNames.contains(name)) {
        orderedNames.add(name);
      }
    }

    final moduleMinutesByName = <String, int>{};
    for (final module in room.modules) {
      if (module.name.trim().isNotEmpty) {
        moduleMinutesByName[module.name.trim()] = module.minute;
      }
    }

    final blocks = <_RoomModuleBlock>[];
    for (final name in orderedNames) {
      final questions = grouped[name] ?? const <QuizQuestion>[];
      if (questions.isEmpty) {
        continue;
      }

      blocks.add(
        _RoomModuleBlock(
          name: name,
          key: _moduleKeyMap[name] ?? 'module_custom',
          questions: questions,
          durationSeconds: _resolveModuleDurationSeconds(
            moduleName: name,
            hasClassicOrder: hasClassicOrder,
            moduleMinute: moduleMinutesByName[name] ?? 0,
            roomMinute: room.quiz.minute,
          ),
        ),
      );
    }

    return blocks;
  }

  int _resolveModuleDurationSeconds({
    required String moduleName,
    required bool hasClassicOrder,
    required int moduleMinute,
    required int roomMinute,
  }) {
    if (hasClassicOrder) {
      switch (moduleName) {
        case 'Module I: Reading and Writing':
        case 'Module II: Reading and Writing':
          return 32 * 60;
        case 'Module I: Math':
        case 'Module II: Math':
          return 35 * 60;
      }
    }

    if (moduleMinute > 0) return moduleMinute * 60;
    if (roomMinute > 0) return roomMinute * 60;
    return 0;
  }

  void _setupTimerForActiveModule() {
    _timer?.cancel();
    final module = _activeModule;
    if (module == null || module.durationSeconds <= 0) {
      return;
    }

    final saved = _moduleTimes[module.key];
    _remainingSeconds = saved == null
        ? module.durationSeconds
        : saved.clamp(0, module.durationSeconds);
    _moduleTimes[module.key] = _remainingSeconds;
    if ((_remainingSeconds ?? 0) <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds == null) {
        return;
      }

      final next = _remainingSeconds! - 1;
      if (next <= 0) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _moduleTimes[module.key] = 0;
        });
        _finishCurrentModule(autoTriggered: true);
        return;
      }

      setState(() {
        _remainingSeconds = next;
        _moduleTimes[module.key] = next;
      });
    });
  }

  Future<void> _finishCurrentModule({required bool autoTriggered}) async {
    if (_activeModuleIndex >= _modules.length - 1) {
      await _submit(autoSubmit: autoTriggered);
      return;
    }

    final currentModuleName = _activeModule?.name ?? '';
    if (widget.room.isExam &&
        currentModuleName == 'Module II: Reading and Writing') {
      _startBreak();
      return;
    }

    await _runLoadingTransition(() {
      setState(() {
        _activeModuleIndex += 1;
        _currentQuestionIndex = 0;
        _remainingSeconds = null;
        _showModuleReview = false;
      });
      _setupTimerForActiveModule();
    });
  }

  void _startBreak() {
    _timer?.cancel();
    if (_breakRemainingSeconds == null || _breakRemainingSeconds! <= 0) {
      _breakRemainingSeconds = 10 * 60;
    }
    _breakTimer?.cancel();
    setState(() {
      _showModuleReview = false;
    });

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _breakRemainingSeconds == null) {
        timer.cancel();
        return;
      }

      if (_breakRemainingSeconds! <= 1) {
        timer.cancel();
        _resumeFromBreak();
        return;
      }

      setState(() {
        _breakRemainingSeconds = _breakRemainingSeconds! - 1;
      });
    });
  }

  int _findModuleIndexByName(String moduleName) {
    for (var i = 0; i < _modules.length; i++) {
      if (_modules[i].name == moduleName) {
        return i;
      }
    }
    return -1;
  }

  void _resumeFromBreak() {
    _breakTimer?.cancel();
    final mathIndex = _findModuleIndexByName('Module I: Math');
    setState(() {
      _breakRemainingSeconds = null;
      _activeModuleIndex = mathIndex >= 0
          ? mathIndex
          : (_activeModuleIndex + 1).clamp(0, _modules.length - 1);
      _currentQuestionIndex = 0;
      _showModuleReview = false;
      _remainingSeconds = null;
    });
    _setupTimerForActiveModule();
  }

  Future<void> _openDirections() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Directions'),
          content: const Text(
            'Đọc kỹ câu hỏi và chọn đáp án đúng nhất. Bạn có thể đánh dấu câu hỏi để review trước khi sang module tiếp theo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _toggleMarkForReview(QuizQuestion question) {
    setState(() {
      _markedForReview[question.id] = !(_markedForReview[question.id] == true);
    });
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _goNext() async {
    _dismissKeyboard();
    final questions = _activeQuestions;
    if (questions.isEmpty) {
      return;
    }

    final currentQuestion = questions[_currentQuestionIndex];
    if (!widget.room.isExam && _isChoiceQuestion(currentQuestion)) {
      final hasSelected =
          (_selectedOptions[currentQuestion.id] ?? '').isNotEmpty;
      final checked = _exerciseChecked[currentQuestion.id] == true;
      if (hasSelected && !checked) {
        setState(() {
          _exerciseChecked[currentQuestion.id] = true;
        });
        return;
      }
    }

    if (_currentQuestionIndex < questions.length - 1) {
      setState(() {
        _currentQuestionIndex += 1;
      });
      return;
    }
    setState(() {
      _showModuleReview = true;
    });
  }

  void _goPrevious() {
    _dismissKeyboard();
    if (_showModuleReview) {
      setState(() {
        _showModuleReview = false;
        _currentQuestionIndex = _activeQuestions.isEmpty
            ? 0
            : _activeQuestions.length - 1;
      });
      return;
    }
    if (_currentQuestionIndex <= 0) {
      return;
    }

    setState(() {
      _currentQuestionIndex -= 1;
    });
  }

  Map<String, dynamic> _buildSubmitModuleTimes() {
    final payload = <String, dynamic>{
      'rw1': null,
      'rw2': null,
      'm1': null,
      'm2': null,
      'module_custom': null,
    };
    payload.addAll(_moduleTimes);

    final module = _activeModule;
    if (module != null && _remainingSeconds != null) {
      payload[module.key] = _remainingSeconds;
    }
    return payload;
  }

  Future<void> _runLoadingTransition(
    FutureOr<void> Function() onCompleted,
  ) async {
    _timer?.cancel();
    _breakTimer?.cancel();
    if (mounted) {
      setState(() {
        _showLoadingScreen = true;
      });
    }

    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) {
      return;
    }

    await Future<void>.sync(onCompleted);
    if (!mounted) {
      return;
    }

    setState(() {
      _showLoadingScreen = false;
    });
  }

  Future<void> _submit({bool autoSubmit = false}) async {
    if (_isSubmitting) {
      return;
    }

    _timer?.cancel();
    _breakTimer?.cancel();
    setState(() {
      _isSubmitting = true;
      _showLoadingScreen = true;
    });

    try {
      final submitFuture = QuizDetailRepository.instance.submitQuiz(
        room: widget.room,
        selectedOptions: _selectedOptions,
        textAnswers: _textAnswers,
        markedFlags: _markedForReview,
        moduleTimes: _buildSubmitModuleTimes(),
        isSingleModule: false,
        selectedModule: null,
      );
      final delayFuture = Future<void>.delayed(const Duration(seconds: 5));
      final submit = await submitFuture;
      await delayFuture;

      if (!mounted) {
        return;
      }

      await _unlockOrientation();
      if (!mounted) {
        return;
      }

      setState(() {
        _showLoadingScreen = false;
      });

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => QuizCongratulationsView(
            resultUuid: submit.uuid,
            quizName: widget.room.quiz.name,
            questionCount: widget.room.quiz.questionCount,
          ),
        ),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            autoSubmit
                ? 'Hết giờ nhưng nộp bài thất bại: ${error.message}'
                : error.message,
          ),
        ),
      );
      _setupTimerForActiveModule();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _showLoadingScreen = false;
        });
      }
    }
  }

  Future<void> _onBackPressed() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Thoát phòng thi?'),
          content: const Text(
            'Nếu thoát lúc này, tiến trình làm bài hiện tại sẽ không được lưu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Thoát'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _openQuestionBoard() async {
    _dismissKeyboard();
    final questions = _activeQuestions;
    if (questions.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeModule?.name ?? 'Question Board',
                  style: const TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(questions.length, (index) {
                    final question = questions[index];
                    final isCurrent = index == _currentQuestionIndex;
                    final isAnswered = _isQuestionAnswered(question);
                    final isMarked = _markedForReview[question.id] == true;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _currentQuestionIndex = index;
                        });
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.black
                              : isAnswered
                              ? QuizDetailPalette.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAnswered || isCurrent
                                ? Colors.transparent
                                : QuizDetailPalette.border,
                            style: isAnswered
                                ? BorderStyle.solid
                                : BorderStyle.solid,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCurrent || isAnswered
                                      ? Colors.white
                                      : QuizDetailPalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isMarked)
                              const Positioned(
                                right: -4,
                                top: -4,
                                child: Icon(
                                  Icons.bookmark_rounded,
                                  size: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCalculator() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CalculatorDialog(),
    );
  }

  Future<void> _openReference() async {
    await showDialog<void>(
      context: context,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 860,
            height: 520,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Reference',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: QuizDetailPalette.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        'https://worksheets.clipart-library.com/images2/sat-prep-math-worksheet/sat-prep-math-worksheet-15.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoadingScreen) {
      return const Scaffold(body: _ExamLoadingScreen());
    }

    if (_modules.isEmpty || _activeQuestions.isEmpty) {
      return Scaffold(
        backgroundColor: QuizDetailPalette.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            widget.room.quiz.name,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: const Center(
          child: Text(
            'Phòng thi hiện chưa có câu hỏi để hiển thị.',
            style: TextStyle(color: QuizDetailPalette.textSecondary),
          ),
        ),
      );
    }

    final activeModule = _activeModule!;
    final questions = activeModule.questions;
    final safeIndex = _currentQuestionIndex.clamp(0, questions.length - 1);
    final question = questions[safeIndex];
    final questionIndexLabel = safeIndex + 1;
    final username = AuthRepository.instance.currentUser?.name.trim();
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.height < 560 || viewport.width < 980;
    final topVerticalPadding = compact ? 0.0 : 1.0;
    final moduleTitleSize = compact ? 11.0 : 13.0;
    final timerFontSize = compact ? 14.0 : 16.0;
    final timerIconSize = compact ? 13.0 : 16.0;
    final quizTitleFontSize = compact ? 9.0 : 10.0;
    final quizTitleVerticalPadding = compact ? 0.0 : 2.0;
    final panelMarginVertical = compact ? 1.0 : 3.0;
    final panelPadding = compact ? 3.0 : 5.0;
    final contentFontSize = compact ? 14.0 : 16.0;
    final optionFontSize = compact ? 13.0 : 15.0;
    final optionCircleSize = compact ? 24.0 : 30.0;
    final questionTagSize = compact ? 18.0 : 24.0;
    final footerVerticalPadding = compact ? 0.0 : 2.0;
    final footerHorizontalPadding = compact ? 4.0 : 6.0;
    final questionBoardLabel = compact
        ? 'Q $questionIndexLabel/${questions.length}'
        : 'Question $questionIndexLabel of ${questions.length}';
    final isOnBreak = _breakRemainingSeconds != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onBackPressed();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        body: GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Column(
              children: [
                if (isOnBreak)
                  Expanded(
                    child: _BreakScreen(
                      examName: widget.room.quiz.name,
                      breakSeconds: _breakRemainingSeconds ?? 0,
                      userName: (username?.isNotEmpty == true)
                          ? username!
                          : 'Edly',
                      onResumeNow: _resumeFromBreak,
                    ),
                  )
                else ...[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 16,
                      vertical: topVerticalPadding,
                    ),
                    color: const Color(0xFFE6EDF8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeModule.name,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: moduleTitleSize,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              TextButton(
                                onPressed: _openDirections,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: compact
                                      ? VisualDensity.compact
                                      : VisualDensity.standard,
                                ),
                                child: Text(
                                  'Directions',
                                  style: TextStyle(fontSize: compact ? 11 : 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_timerVisible && _remainingSeconds != null)
                                Text(
                                  _formatSeconds(_remainingSeconds!),
                                  style: TextStyle(
                                    fontSize: timerFontSize,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              else
                                Icon(Icons.timer_outlined, size: timerIconSize),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _timerVisible = !_timerVisible;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: compact
                                      ? VisualDensity.compact
                                      : VisualDensity.standard,
                                ),
                                child: Text(
                                  _timerVisible ? 'Hide' : 'Show',
                                  style: TextStyle(fontSize: compact ? 11 : 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _TopAction(
                                  icon: Icons.calculate_outlined,
                                  label: 'Calculator',
                                  onTap: _openCalculator,
                                  compact: compact,
                                ),
                                SizedBox(width: compact ? 4 : 8),
                                _TopAction(
                                  icon: Icons.functions_rounded,
                                  label: 'Reference',
                                  onTap: _openReference,
                                  compact: compact,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: const Color(0xFF1A2264),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 16,
                      vertical: quizTitleVerticalPadding,
                    ),
                    child: Text(
                      widget.room.quiz.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: quizTitleFontSize,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: _showModuleReview
                        ? _buildModuleReviewPane(
                            moduleName: activeModule.name,
                            questions: questions,
                            compact: compact,
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(
                                    compact ? 6 : 12,
                                    panelMarginVertical,
                                    compact ? 2 : 4,
                                    panelMarginVertical,
                                  ),
                                  padding: EdgeInsets.all(panelPadding),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: QuizDetailPalette.border,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.only(
                                            right: 10,
                                          ),
                                          child: _buildQuestionContent(
                                            question: question,
                                            raw: question.content.isNotEmpty
                                                ? question.content
                                                : question.title,
                                            style: TextStyle(
                                              color:
                                                  QuizDetailPalette.textPrimary,
                                              fontSize: contentFontSize,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  margin: EdgeInsets.fromLTRB(
                                    compact ? 2 : 4,
                                    panelMarginVertical,
                                    compact ? 6 : 12,
                                    panelMarginVertical,
                                  ),
                                  padding: EdgeInsets.all(panelPadding),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: QuizDetailPalette.border,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: compact ? 6 : 10,
                                          vertical: compact ? 2 : 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: QuizDetailPalette.border,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              constraints: BoxConstraints(
                                                minWidth: questionTagSize,
                                                minHeight: questionTagSize,
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: compact ? 4 : 6,
                                              ),
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '$questionIndexLabel',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: compact ? 10 : 12,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: compact ? 6 : 10),
                                            Expanded(
                                              child: Text(
                                                'Mark for Review',
                                                style: TextStyle(
                                                  color: QuizDetailPalette
                                                      .textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: compact ? 8 : 10,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _toggleMarkForReview(
                                                    question,
                                                  ),
                                              constraints: const BoxConstraints(
                                                minWidth: 28,
                                                minHeight: 28,
                                              ),
                                              padding: EdgeInsets.zero,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              iconSize: compact ? 14 : 16,
                                              icon: Icon(
                                                _markedForReview[question.id] ==
                                                        true
                                                    ? Icons.bookmark_rounded
                                                    : Icons
                                                          .bookmark_border_rounded,
                                                color:
                                                    _markedForReview[question
                                                            .id] ==
                                                        true
                                                    ? Colors.redAccent
                                                    : QuizDetailPalette
                                                          .textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: compact ? 6 : 8),
                                      Expanded(
                                        child: _isChoiceQuestion(question)
                                            ? ListView.separated(
                                                itemCount:
                                                    question.options.length,
                                                separatorBuilder:
                                                    (context, index) =>
                                                        SizedBox(
                                                          height: compact
                                                              ? 6
                                                              : 10,
                                                        ),
                                                itemBuilder: (context, index) {
                                                  final option =
                                                      question.options[index];
                                                  final selected =
                                                      _selectedOptions[question
                                                          .id] ==
                                                      option.id;
                                                  final checked =
                                                      _exerciseChecked[question
                                                          .id] ==
                                                      true;
                                                  final showExerciseCheckState =
                                                      !widget.room.isExam &&
                                                      checked;
                                                  final optionColorState =
                                                      _optionStateForExercise(
                                                        showExerciseCheckState:
                                                            showExerciseCheckState,
                                                        option: option,
                                                        selected: selected,
                                                      );
                                                  return InkWell(
                                                    onTap: () {
                                                      setState(() {
                                                        _selectedOptions[question
                                                                .id] =
                                                            option.id;
                                                        _exerciseChecked[question
                                                                .id] =
                                                            false;
                                                      });
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: compact
                                                                ? 8
                                                                : 12,
                                                            vertical: compact
                                                                ? 8
                                                                : 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: optionColorState
                                                            .backgroundColor,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              optionColorState
                                                                  .borderColor,
                                                          width: selected
                                                              ? 2
                                                              : 1.5,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                            width:
                                                                optionCircleSize,
                                                            height:
                                                                optionCircleSize,
                                                            alignment: Alignment
                                                                .center,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: optionColorState
                                                                    .borderColor,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              String.fromCharCode(
                                                                65 + index,
                                                              ),
                                                              style: TextStyle(
                                                                color: optionColorState
                                                                    .textColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: compact
                                                                ? 8
                                                                : 10,
                                                          ),
                                                          Expanded(
                                                            child: _buildQuestionContent(
                                                              question:
                                                                  question,
                                                              raw: option
                                                                  .content,
                                                              option: option,
                                                              style: TextStyle(
                                                                color: optionColorState
                                                                    .contentColor,
                                                                fontSize:
                                                                    optionFontSize,
                                                                height: 1.35,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              )
                                            : TextFormField(
                                                key: ValueKey<String>(
                                                  'text_${question.id}',
                                                ),
                                                initialValue:
                                                    _textAnswers[question.id] ??
                                                    '',
                                                maxLines: 6,
                                                decoration: const InputDecoration(
                                                  hintText:
                                                      'Nhập câu trả lời của bạn',
                                                  border: OutlineInputBorder(),
                                                ),
                                                onTapOutside: (_) =>
                                                    _dismissKeyboard(),
                                                textInputAction:
                                                    TextInputAction.done,
                                                onChanged: (value) {
                                                  _textAnswers[question.id] =
                                                      value;
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  Container(
                    color: const Color(0xFFE6EDF8),
                    padding: EdgeInsets.symmetric(
                      horizontal: footerHorizontalPadding,
                      vertical: footerVerticalPadding,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/edly-logo.png',
                                height: compact ? 22 : 28,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: compact ? 18 : 22,
                                color: Colors.black26,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  (username?.isNotEmpty == true)
                                      ? username!
                                      : 'Edly',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 12 : 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.center,
                            child: _showModuleReview
                                ? const SizedBox.shrink()
                                : TextButton(
                                    onPressed: _openQuestionBoard,
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.black87,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 10 : 12,
                                        vertical: compact ? 6 : 8,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      questionBoardLabel,
                                      style: TextStyle(
                                        fontSize: compact ? 12 : 14,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton(
                                  onPressed: _showModuleReview
                                      ? _goPrevious
                                      : (safeIndex == 0 ? null : _goPrevious),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size(
                                      compact ? 56 : 64,
                                      compact ? 28 : 32,
                                    ),
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : VisualDensity.standard,
                                  ),
                                  child: Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: compact ? 12 : 14,
                                    ),
                                  ),
                                ),
                                SizedBox(width: compact ? 6 : 8),
                                FilledButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () async {
                                          if (_showModuleReview) {
                                            await _finishCurrentModule(
                                              autoTriggered: false,
                                            );
                                            return;
                                          }
                                          await _goNext();
                                        },
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size(
                                      compact ? 60 : 68,
                                      compact ? 28 : 32,
                                    ),
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : VisualDensity.standard,
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _showModuleReview
                                              ? (_activeModuleIndex >=
                                                        _modules.length - 1
                                                    ? 'Submit'
                                                    : 'Next')
                                              : _nextButtonLabel(
                                                  question: question,
                                                  isLastQuestion:
                                                      safeIndex >=
                                                      questions.length - 1,
                                                ),
                                          style: TextStyle(
                                            fontSize: compact ? 12 : 14,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isQuestionAnswered(QuizQuestion question) {
    return (_selectedOptions[question.id] ?? '').isNotEmpty ||
        (_textAnswers[question.id] ?? '').trim().isNotEmpty;
  }

  bool _isChoiceQuestion(QuizQuestion question) {
    final type = question.type.toLowerCase();
    if (type == 'single-choice') {
      return true;
    }
    if (_isTextAnswerQuestion(question)) {
      return false;
    }

    return question.options.isNotEmpty;
  }

  bool _isTextAnswerQuestion(QuizQuestion question) {
    final type = question.type.toLowerCase();
    return type == 'essay' || type == 'short-answer' || type == 'numeric';
  }

  String _nextButtonLabel({
    required QuizQuestion question,
    required bool isLastQuestion,
  }) {
    if (!widget.room.isExam && _isChoiceQuestion(question)) {
      final hasSelected = (_selectedOptions[question.id] ?? '').isNotEmpty;
      final checked = _exerciseChecked[question.id] == true;
      if (hasSelected && !checked) {
        return 'Check';
      }
    }

    if (isLastQuestion) {
      if (_activeModuleIndex >= _modules.length - 1) {
        return 'Submit';
      }
      return 'Next Module';
    }
    return 'Next';
  }

  _OptionColorState _optionStateForExercise({
    required bool showExerciseCheckState,
    required QuizOption option,
    required bool selected,
  }) {
    if (!showExerciseCheckState) {
      if (selected) {
        return const _OptionColorState(
          backgroundColor: Color(0xFFEEF2FF),
          borderColor: QuizDetailPalette.primary,
          textColor: QuizDetailPalette.primary,
          contentColor: QuizDetailPalette.textPrimary,
        );
      }
      return const _OptionColorState(
        backgroundColor: Colors.white,
        borderColor: Color(0xFF4B4B4B),
        textColor: Color(0xFF4B4B4B),
        contentColor: QuizDetailPalette.textPrimary,
      );
    }

    if (option.isCorrect) {
      return const _OptionColorState(
        backgroundColor: Color(0xFFDCFCE7),
        borderColor: Color(0xFF16A34A),
        textColor: Color(0xFF166534),
        contentColor: Color(0xFF166534),
      );
    }

    if (selected && !option.isCorrect) {
      return const _OptionColorState(
        backgroundColor: Color(0xFFFEE2E2),
        borderColor: Color(0xFFDC2626),
        textColor: Color(0xFFB91C1C),
        contentColor: Color(0xFFB91C1C),
      );
    }

    return const _OptionColorState(
      backgroundColor: Color(0xFFF8FAFC),
      borderColor: Color(0xFFCBD5E1),
      textColor: Color(0xFF64748B),
      contentColor: Color(0xFF64748B),
    );
  }

  Widget _buildModuleReviewPane({
    required String moduleName,
    required List<QuizQuestion> questions,
    required bool compact,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 24,
        compact ? 8 : 14,
        compact ? 12 : 24,
        compact ? 10 : 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Check Your Work',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 24 : 34,
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            "On test day, you won't be able to move on to the next module until time expires.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuizDetailPalette.textSecondary,
              fontSize: compact ? 12 : 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "For these practice tests, you can click Next when you're ready to move on.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuizDetailPalette.textSecondary,
              fontSize: compact ? 12 : 15,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 16,
              compact ? 8 : 12,
              compact ? 10 : 16,
              compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: QuizDetailPalette.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        moduleName,
                        style: TextStyle(
                          color: QuizDetailPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 18 : 30,
                        ),
                      ),
                    ),
                    _reviewLegend(
                      icon: Icons.crop_square_rounded,
                      color: const Color(0xFF94A3B8),
                      text: 'Unanswered',
                      compact: compact,
                    ),
                    const SizedBox(width: 10),
                    _reviewLegend(
                      icon: Icons.bookmark_rounded,
                      color: Colors.redAccent,
                      text: 'For Review',
                      compact: compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: compact ? 8 : 10,
                  runSpacing: compact ? 8 : 10,
                  children: List.generate(questions.length, (index) {
                    final item = questions[index];
                    final answered = _isQuestionAnswered(item);
                    final marked = _markedForReview[item.id] == true;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _currentQuestionIndex = index;
                          _showModuleReview = false;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: compact ? 34 : 40,
                        height: compact ? 34 : 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: answered
                              ? QuizDetailPalette.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: answered
                                ? QuizDetailPalette.primary
                                : const Color(0xFF94A3B8),
                            style: answered
                                ? BorderStyle.solid
                                : BorderStyle.solid,
                            width: answered ? 1.4 : 1,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: answered
                                      ? Colors.white
                                      : QuizDetailPalette.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 14 : 16,
                                ),
                              ),
                            ),
                            if (marked)
                              const Positioned(
                                right: -4,
                                top: -5,
                                child: Icon(
                                  Icons.bookmark_rounded,
                                  size: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewLegend({
    required IconData icon,
    required Color color,
    required String text,
    required bool compact,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 13 : 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: QuizDetailPalette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: compact ? 10 : 12,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionContent({
    required QuizQuestion question,
    required String raw,
    required TextStyle style,
    QuizOption? option,
  }) {
    if (_shouldUseHtmlRenderer(question, raw, option: option)) {
      return _RichQuestionHtmlView(
        html: _renderRichHtml(question, raw, option: option),
        textStyle: style,
        maxImageHeight: option == null ? 180 : 120,
        interactive: false,
        inline: option != null,
      );
    }

    final chunks = _tokenizeContent(raw, question, option: option);
    if (chunks.isEmpty) {
      final text = _renderText(raw);
      if (text.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(text, style: style);
    }

    final imageMaxHeight = option == null ? 132.0 : 86.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: chunks.map((chunk) {
        if (chunk.type == _ContentChunkType.imageUrl ||
            chunk.type == _ContentChunkType.imageBytes) {
          final imageChild = chunk.type == _ContentChunkType.imageBytes
              ? Image.memory(chunk.bytes!, fit: BoxFit.contain)
              : Image.network(
                  chunk.value,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Text(
                    '[Không tải được công thức/hình ảnh]',
                    style: style.copyWith(
                      color: QuizDetailPalette.textMuted,
                      fontSize: (style.fontSize ?? 14) - 1,
                    ),
                  ),
                );
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: imageMaxHeight),
              child: imageChild,
            ),
          );
        }

        if (chunk.type == _ContentChunkType.mathText) {
          final text = _renderText(chunk.value);
          if (text.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: style.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final text = _renderText(chunk.value);
        if (text.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(text, style: style);
      }).toList(),
    );
  }

  bool _shouldUseHtmlRenderer(
    QuizQuestion question,
    String raw, {
    QuizOption? option,
  }) {
    final content = raw.trim().toLowerCase();
    if (content.isEmpty) {
      return false;
    }

    if (content.contains('<math') ||
        content.contains('[math:') ||
        content.contains('[image:') ||
        content.contains('<table') ||
        content.contains('[*')) {
      return true;
    }

    if (option != null) {
      return option.maths.isNotEmpty || option.images.isNotEmpty;
    }

    return question.maths.isNotEmpty || question.images.isNotEmpty;
  }

  String _renderRichHtml(
    QuizQuestion question,
    String raw, {
    QuizOption? option,
  }) {
    if (raw.trim().isEmpty) {
      return '';
    }

    var html = _convertTextTableToHtml(raw);
    final maths = <QuizMathAsset>[...question.maths, ...?option?.maths];
    final images = <QuizImageAsset>[...question.images, ...?option?.images];

    for (final mathAsset in maths) {
      final placeholder = '[Math:${mathAsset.id}]';
      final rendered = mathAsset.mathml.trim().isNotEmpty
          ? '<span class="math-placeholder" data-math-id="${mathAsset.id}">${mathAsset.mathml}</span>'
          : '<span class="math-fallback">${_renderMathAsText(mathAsset)}</span>';
      html = html.replaceAll(placeholder, rendered);
    }

    for (final image in images) {
      final placeholder = '[Image:${image.id}]';
      final url = _normalizeAssetUrl(image.path);
      final rendered =
          '<div class="image-block"><img src="$url" data-image-id="${image.id}" alt="question image" /></div>';
      html = html.replaceAll(placeholder, rendered);
    }

    if (!html.toLowerCase().contains('<math')) {
      final missingMath = maths
          .where((item) => item.mathml.trim().isNotEmpty)
          .where((item) => !html.contains('data-math-id="${item.id}"'))
          .map(
            (item) =>
                '<div class="math-block" data-math-id="${item.id}">${item.mathml}</div>',
          )
          .join();
      if (missingMath.isNotEmpty) {
        html = '$html<div class="math-stack">$missingMath</div>';
      }
    }

    if (!html.toLowerCase().contains('<img')) {
      final missingImages = images
          .where((item) => item.path.trim().isNotEmpty)
          .map(
            (item) =>
                '<div class="image-block"><img src="${_normalizeAssetUrl(item.path)}" data-image-id="${item.id}" alt="question image" /></div>',
          )
          .join();
      if (missingImages.isNotEmpty) {
        html = '$html<div class="image-stack">$missingImages</div>';
      }
    }

    return _sanitizeRichHtml(_normalizeInlineHtmlSources(html));
  }

  String _convertTextTableToHtml(String text) {
    if (text.isEmpty) {
      return text;
    }

    final protected = _protectPlaceholders(text);
    final protectedText = protected.protectedText;
    final rows = <({int start, int end, List<String> cells})>[];
    final rowRegExp = RegExp(r'\[\*\s*([^*]+?)\s*\*\]');

    bool isBlank(String value) {
      return value.replaceAll(
            RegExp(
              r'^(?:\s|<br[^>]*>|\n|<\/?(?:p|div)[^>]*>)*$',
              caseSensitive: false,
            ),
            '',
          ) ==
          '';
    }

    for (final match in rowRegExp.allMatches(protectedText)) {
      rows.add((
        start: match.start,
        end: match.end,
        cells: (match.group(1) ?? '')
            .split('|')
            .map((cell) => cell.trim().isEmpty ? ' ' : cell.trim())
            .toList(),
      ));
    }

    if (rows.isEmpty) {
      return _restorePlaceholders(protectedText, protected.saved);
    }

    final groups = <({int start, int end, List<List<String>> rows})>[];
    ({int start, int end, List<List<String>> rows})? current;

    for (final row in rows) {
      if (current == null) {
        current = (start: row.start, end: row.end, rows: [row.cells]);
        groups.add(current);
        continue;
      }

      final gap = protectedText.substring(current.end, row.start);
      if (isBlank(gap)) {
        current = (
          start: current.start,
          end: row.end,
          rows: [...current.rows, row.cells],
        );
        groups[groups.length - 1] = current;
      } else {
        current = (start: row.start, end: row.end, rows: [row.cells]);
        groups.add(current);
      }
    }

    var output = protectedText;
    for (var index = groups.length - 1; index >= 0; index--) {
      final group = groups[index];
      final rowsHtml = StringBuffer();
      for (var rowIndex = 0; rowIndex < group.rows.length; rowIndex++) {
        final row = group.rows[rowIndex];
        final isHeader = rowIndex == 0;
        final tag = isHeader ? 'th' : 'td';
        final style = isHeader
            ? 'border:1px solid #cbd5e1;padding:8px;background:#f8fafc;font-weight:700;'
            : 'border:1px solid #cbd5e1;padding:8px;';
        rowsHtml.write(
          '<tr>${row.map((cell) => '<$tag style="$style">$cell</$tag>').join()}</tr>',
        );
      }
      final tableHtml = '<table class="text-table">$rowsHtml</table>';
      output =
          '${output.substring(0, group.start)}$tableHtml${output.substring(group.end)}';
    }

    return _restorePlaceholders(output, protected.saved);
  }

  ({String protectedText, List<String> saved}) _protectPlaceholders(
    String text,
  ) {
    final saved = <String>[];
    final protectedText = text.replaceAllMapped(
      RegExp(r'\[(?:Math|Image):[^\]]+\]', caseSensitive: false),
      (match) {
        final index = saved.length;
        saved.add(match.group(0)!);
        return '__PH_${index}__';
      },
    );
    return (protectedText: protectedText, saved: saved);
  }

  String _restorePlaceholders(String text, List<String> saved) {
    return text.replaceAllMapped(RegExp(r'__PH_(\d+)__'), (match) {
      final index = int.tryParse(match.group(1) ?? '') ?? -1;
      if (index < 0 || index >= saved.length) {
        return match.group(0)!;
      }
      return saved[index];
    });
  }

  String _normalizeInlineHtmlSources(String html) {
    return html.replaceAllMapped(
      RegExp(r'''src=(["'])(.*?)\1''', caseSensitive: false),
      (match) {
        final quote = match.group(1) ?? '"';
        final src = match.group(2) ?? '';
        final normalized = _normalizeAssetUrl(src);
        return 'src=$quote$normalized$quote';
      },
    );
  }

  String _sanitizeRichHtml(String html) {
    if (html.trim().isEmpty) {
      return '';
    }

    var normalized = html;
    normalized = normalized.replaceAll(
      RegExp(
        r'<span\b[^>]*>(?:\s|&nbsp;|&#160;|<br\s*/?>)*</span>',
        caseSensitive: false,
      ),
      '',
    );
    normalized = normalized.replaceAll(
      RegExp(
        r'<(?:p|div)\b[^>]*>(?:\s|&nbsp;|&#160;|<br\s*/?>)*</(?:p|div)>',
        caseSensitive: false,
      ),
      '',
    );
    normalized = normalized.replaceAll(
      RegExp(r'(?:<br\s*/?>\s*){3,}', caseSensitive: false),
      '<br>',
    );
    normalized = normalized.replaceAll(
      RegExp(r'>\s+<', caseSensitive: false),
      '><',
    );
    return normalized.trim();
  }

  List<_ContentChunk> _tokenizeContent(
    String raw,
    QuizQuestion question, {
    QuizOption? option,
  }) {
    final content = raw.trim();
    if (content.isEmpty) {
      return const [];
    }

    final mathMap = _buildMathMap(question, option: option);
    final imageMap = _buildImageMap(question, option: option);
    final parts = <String>[];
    const pattern = r'(\[Math:[^\]]+\]|\[Image:[^\]]+\])';
    final splitter = RegExp(pattern, caseSensitive: false);
    var hasPlaceholderToken = false;

    content.splitMapJoin(
      splitter,
      onMatch: (match) {
        hasPlaceholderToken = true;
        parts.add(match.group(0) ?? '');
        return '';
      },
      onNonMatch: (text) {
        if (text.isNotEmpty) {
          parts.add(text);
        }
        return '';
      },
    );

    final chunks = <_ContentChunk>[];
    for (final part in parts) {
      final match = splitter.firstMatch(part);
      if (match == null || match.group(0) != part) {
        chunks.add(_ContentChunk.text(part));
        continue;
      }

      if (part.toLowerCase().startsWith('[math:')) {
        final rawId = part.substring(6, part.length - 1).trim();
        final math = mathMap[_normalizePlaceholderId(rawId)];
        if (math == null) {
          chunks.add(_ContentChunk.text(part));
          continue;
        }

        final mathImage = _resolveInlineImageChunk(math.bin);
        if (mathImage != null) {
          chunks.add(mathImage);
          continue;
        }

        final mathText = _renderMathAsText(math);
        if (mathText.isNotEmpty) {
          chunks.add(_ContentChunk.mathText(mathText));
        }
        continue;
      }

      if (part.toLowerCase().startsWith('[image:')) {
        final rawId = part.substring(7, part.length - 1).trim();
        final image = imageMap[_normalizePlaceholderId(rawId)];
        if (image != null) {
          final imageChunk = _resolveInlineImageChunk(image.path);
          if (imageChunk != null) {
            chunks.add(imageChunk);
          }
        }
        continue;
      }
    }

    final compactChunks = _compactTextChunks(chunks);

    // Một số câu không gắn placeholder nhưng vẫn có maths trong payload.
    // Fallback: append công thức để không mất dữ liệu hiển thị.
    if (!hasPlaceholderToken) {
      final fallbackAssets = option == null ? question.maths : option.maths;
      if (fallbackAssets.isNotEmpty) {
        final extended = <_ContentChunk>[
          ...compactChunks,
          ...fallbackAssets.map((asset) {
            final imageChunk = _resolveInlineImageChunk(asset.bin);
            if (imageChunk != null) {
              return imageChunk;
            }
            final mathText = _renderMathAsText(asset);
            if (mathText.isNotEmpty) {
              return _ContentChunk.mathText(mathText);
            }
            return null;
          }).whereType<_ContentChunk>(),
        ];
        return _compactTextChunks(extended);
      }
    }

    return compactChunks;
  }

  Map<String, QuizMathAsset> _buildMathMap(
    QuizQuestion question, {
    QuizOption? option,
  }) {
    final map = <String, QuizMathAsset>{};
    final items = <QuizMathAsset>[...question.maths, ...?option?.maths];
    for (final item in items) {
      final key = _normalizePlaceholderId(item.id);
      if (key.isNotEmpty) {
        map[key] = item;
      }
    }
    return map;
  }

  Map<String, QuizImageAsset> _buildImageMap(
    QuizQuestion question, {
    QuizOption? option,
  }) {
    final map = <String, QuizImageAsset>{};
    final items = <QuizImageAsset>[...question.images, ...?option?.images];
    for (final item in items) {
      final key = _normalizePlaceholderId(item.id);
      if (key.isNotEmpty) {
        map[key] = item;
      }
    }
    return map;
  }

  String _normalizePlaceholderId(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized
        .replaceFirst(RegExp(r'^math_'), '')
        .replaceFirst(RegExp(r'^image_'), '');
  }

  List<_ContentChunk> _compactTextChunks(List<_ContentChunk> chunks) {
    if (chunks.isEmpty) {
      return const [];
    }

    final compact = <_ContentChunk>[];
    for (final chunk in chunks) {
      if (compact.isNotEmpty &&
          compact.last.type == _ContentChunkType.text &&
          chunk.type == _ContentChunkType.text) {
        compact[compact.length - 1] = _ContentChunk.text(
          '${compact.last.value}${chunk.value}',
        );
      } else {
        compact.add(chunk);
      }
    }
    return compact;
  }

  String _normalizeAssetUrl(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return '';
    }

    if (raw.startsWith('data:')) {
      return raw;
    }

    if (raw.startsWith('//')) {
      return 'https:$raw';
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return '${ApiConfig.webBaseUrl}/${raw.replaceFirst(RegExp(r'^/+'), '')}';
  }

  _ContentChunk? _resolveInlineImageChunk(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }

    final dataUri = _decodeDataUri(raw);
    if (dataUri != null) {
      return _ContentChunk.imageBytes(dataUri);
    }

    final base64Only = _decodeRawBase64Image(raw);
    if (base64Only != null) {
      return _ContentChunk.imageBytes(base64Only);
    }

    final normalizedUrl = _normalizeAssetUrl(raw);
    if (normalizedUrl.isEmpty || normalizedUrl.startsWith('data:')) {
      return null;
    }
    return _ContentChunk.imageUrl(normalizedUrl);
  }

  Uint8List? _decodeDataUri(String value) {
    final match = RegExp(r'^data:image/[^;]+;base64,(.+)$').firstMatch(value);
    if (match == null) {
      return null;
    }

    try {
      return base64Decode(match.group(1)!);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _decodeRawBase64Image(String value) {
    final looksLikeBase64 = RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(value);
    if (!looksLikeBase64 || value.length < 100) {
      return null;
    }

    try {
      return base64Decode(value.replaceAll('\n', '').replaceAll('\r', ''));
    } catch (_) {
      return null;
    }
  }

  String _renderMathAsText(QuizMathAsset asset) {
    if (asset.mathml.trim().isNotEmpty) {
      return _renderMathMlBlock(asset.mathml);
    }

    final source = asset.omml;
    if (source.trim().isEmpty) {
      return '';
    }
    return _normalizeRenderedMath(
      source
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .trim(),
    );
  }

  String _renderText(String value) {
    final withMathBlocks = value.replaceAllMapped(
      RegExp(r'<math[\s\S]*?</math>', caseSensitive: false),
      (match) => ' ${_renderMathMlBlock(match.group(0) ?? '')} ',
    );

    return withMathBlocks
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|li|h[1-6])>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  String _renderMathMlBlock(String block) {
    if (block.trim().isEmpty) {
      return '';
    }

    try {
      final doc = xml.XmlDocument.parse(block);
      final raw = _renderMathXmlNodes(doc.children);
      return _normalizeRenderedMath(raw);
    } catch (_) {
      return _normalizeRenderedMath(
        block
            .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .trim(),
      );
    }
  }

  String _renderMathXmlNodes(Iterable<xml.XmlNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      buffer.write(_renderMathXmlNode(node));
    }
    return buffer.toString();
  }

  String _renderMathXmlNode(xml.XmlNode node) {
    if (node is xml.XmlText) {
      return node.value;
    }
    if (node is xml.XmlCDATA) {
      return node.value;
    }
    if (node is! xml.XmlElement) {
      return '';
    }

    final tag = node.name.local.toLowerCase();
    final children = node.children.whereType<xml.XmlElement>().toList();

    switch (tag) {
      case 'math':
      case 'mrow':
      case 'mstyle':
      case 'semantics':
      case 'annotation-xml':
      case 'annotation':
        return _renderMathXmlNodes(node.children);
      case 'mtext':
      case 'mi':
      case 'mn':
      case 'mo':
        return node.innerText;
      case 'msup':
        if (children.length < 2) return _renderMathXmlNodes(node.children);
        final base = _renderMathXmlNode(children[0]);
        final exponent = _renderMathXmlNode(children[1]);
        return '$base${_toSuperscript(exponent)}';
      case 'msub':
        if (children.length < 2) return _renderMathXmlNodes(node.children);
        final base = _renderMathXmlNode(children[0]);
        final sub = _renderMathXmlNode(children[1]);
        return '$base${_toSubscript(sub)}';
      case 'msubsup':
        if (children.length < 3) return _renderMathXmlNodes(node.children);
        final base = _renderMathXmlNode(children[0]);
        final sub = _renderMathXmlNode(children[1]);
        final sup = _renderMathXmlNode(children[2]);
        return '$base${_toSubscript(sub)}${_toSuperscript(sup)}';
      case 'mfrac':
        if (children.length < 2) return _renderMathXmlNodes(node.children);
        final num = _renderMathXmlNode(children[0]);
        final den = _renderMathXmlNode(children[1]);
        return '($num)/($den)';
      case 'msqrt':
        return '√(${_renderMathXmlNodes(node.children)})';
      case 'mroot':
        if (children.length < 2) return _renderMathXmlNodes(node.children);
        final base = _renderMathXmlNode(children[0]);
        final degree = _renderMathXmlNode(children[1]);
        return '$base^(1/$degree)';
      case 'mfenced':
        return '(${_renderMathXmlNodes(node.children)})';
      case 'mtable':
        final rows = node.children
            .whereType<xml.XmlElement>()
            .where((el) => el.name.local.toLowerCase() == 'mtr')
            .map(_renderMathXmlNode)
            .where((row) => row.trim().isNotEmpty)
            .join(' ; ');
        return rows;
      case 'mtr':
        final cells = node.children
            .whereType<xml.XmlElement>()
            .where((el) => el.name.local.toLowerCase() == 'mtd')
            .map(_renderMathXmlNode)
            .join(' | ');
        return cells;
      case 'mtd':
        return _renderMathXmlNodes(node.children);
      default:
        return _renderMathXmlNodes(node.children);
    }
  }

  String _toSuperscript(String value) {
    const map = <String, String>{
      '0': '⁰',
      '1': '¹',
      '2': '²',
      '3': '³',
      '4': '⁴',
      '5': '⁵',
      '6': '⁶',
      '7': '⁷',
      '8': '⁸',
      '9': '⁹',
      '+': '⁺',
      '-': '⁻',
      '=': '⁼',
      '(': '⁽',
      ')': '⁾',
      'n': 'ⁿ',
      'i': 'ⁱ',
    };
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final rune in compact.runes) {
      final ch = String.fromCharCode(rune);
      final sup = map[ch];
      if (sup == null) {
        return '^($compact)';
      }
      buffer.write(sup);
    }
    return buffer.toString();
  }

  String _toSubscript(String value) {
    const map = <String, String>{
      '0': '₀',
      '1': '₁',
      '2': '₂',
      '3': '₃',
      '4': '₄',
      '5': '₅',
      '6': '₆',
      '7': '₇',
      '8': '₈',
      '9': '₉',
      '+': '₊',
      '-': '₋',
      '=': '₌',
      '(': '₍',
      ')': '₎',
    };
    final compact = value.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final rune in compact.runes) {
      final ch = String.fromCharCode(rune);
      final sub = map[ch];
      if (sub == null) {
        return '_($compact)';
      }
      buffer.write(sub);
    }
    return buffer.toString();
  }

  String _normalizeRenderedMath(String value) {
    return value
        .replaceAll('\u00A0', ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&times;', '×')
        .replaceAll('&le;', '≤')
        .replaceAll('&ge;', '≥')
        .replaceAll('&ne;', '≠')
        .replaceAll('&minus;', '−')
        .replaceAll('&frasl;', '/')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('( ', '(')
        .replaceAll(' )', ')')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .trim();
  }

  String _formatSeconds(int seconds) {
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 5,
          vertical: compact ? 1 : 2,
        ),
        child: Column(
          children: [
            Icon(icon, size: compact ? 16 : 20),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RichQuestionHtmlView extends StatefulWidget {
  const _RichQuestionHtmlView({
    required this.html,
    required this.textStyle,
    required this.maxImageHeight,
    required this.interactive,
    required this.inline,
  });

  final String html;
  final TextStyle textStyle;
  final double maxImageHeight;
  final bool interactive;
  final bool inline;

  @override
  State<_RichQuestionHtmlView> createState() => _RichQuestionHtmlViewState();
}

class _RichQuestionHtmlViewState extends State<_RichQuestionHtmlView> {
  late final WebViewController _controller;
  double _height = 80;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'HeightObserver',
        onMessageReceived: (message) {
          final nextHeight = double.tryParse(message.message);
          if (nextHeight == null || nextHeight <= 0) {
            return;
          }
          final normalized = nextHeight.clamp(40, 1200).toDouble();
          if (!mounted || (normalized - _height).abs() < 1) {
            return;
          }
          setState(() {
            _height = normalized;
          });
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.prevent,
          onPageFinished: (_) async {
            await _remeasure();
          },
        ),
      );
    _loadHtml();
  }

  @override
  void didUpdateWidget(covariant _RichQuestionHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html ||
        oldWidget.textStyle.fontSize != widget.textStyle.fontSize ||
        oldWidget.maxImageHeight != widget.maxImageHeight) {
      _loadHtml();
    }
  }

  Future<void> _loadHtml() async {
    final html = _buildHtmlDocument();
    await _controller.loadHtmlString(html, baseUrl: ApiConfig.webBaseUrl);
  }

  Future<void> _remeasure() async {
    try {
      await _controller.runJavaScript('measureHeight();');
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        _controller.runJavaScript('measureHeight();');
      });
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        _controller.runJavaScript('measureHeight();');
      });
    } catch (_) {}
  }

  String _buildHtmlDocument() {
    final fontSize = widget.textStyle.fontSize ?? 16;
    final lineHeight = widget.textStyle.height ?? 1.5;
    final fontWeight = (widget.textStyle.fontWeight ?? FontWeight.w500).value;
    final color = _cssColor(widget.textStyle.color ?? Colors.black);

    final rootClass = widget.inline ? 'inline-root' : 'question-html';
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      overflow: hidden;
    }
    body {
      color: $color;
      font-size: ${fontSize}px;
      line-height: $lineHeight;
      font-weight: $fontWeight;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      ${widget.interactive ? '' : 'pointer-events: none; user-select: none;'}
      word-break: normal;
      overflow-wrap: anywhere;
    }
    * {
      box-sizing: border-box;
      max-width: 100%;
    }
    .question-html {
      width: 100%;
    }
    .inline-root {
      display: inline;
      width: auto;
      white-space: normal;
    }
    p, div, span, li, td, th {
      font-size: inherit;
      line-height: inherit;
    }
    .question-html p {
      margin: 0 0 0.28em 0;
    }
    .question-html > p:last-child,
    .question-html > div:last-child,
    .question-html > figure:last-child {
      margin-bottom: 0;
    }
    .question-html div,
    .question-html figure,
    .question-html span {
      margin: 0;
    }
    .inline-root p,
    .inline-root div,
    .inline-root span {
      display: inline;
      margin: 0;
    }
    .inline-root br {
      display: none;
    }
    .inline-root .math-inline {
      display: inline;
    }
    .inline-root math,
    .inline-root math * {
      display: inline;
    }
    .question-html figure {
      width: 100%;
    }
    .question-html p:empty,
    .question-html div:empty,
    .question-html span:empty {
      display: none;
    }
    img {
      max-width: 100%;
      height: auto;
      object-fit: contain;
      display: block;
      margin: 8px auto;
      max-height: ${widget.maxImageHeight}px;
    }
    .image-block, .math-block, .math-stack, .image-stack {
      margin: 8px 0;
    }
    .image-block img,
    .image-stack img {
      margin: 0 auto;
    }
    .table-wrap,
    figure.table {
      display: block;
      width: 100%;
      overflow-x: auto;
      overflow-y: hidden;
      margin: 8px 0;
      -webkit-overflow-scrolling: touch;
    }
    .text-table,
    table {
      width: auto;
      min-width: 100%;
      border-collapse: collapse;
      margin: 0;
      border: 1px solid #cbd5e1;
      table-layout: auto;
    }
    .text-table td,
    .text-table th,
    table td,
    table th {
      border: 1px solid #cbd5e1;
      padding: 8px;
      text-align: left;
      vertical-align: middle;
      white-space: normal;
    }
    .text-table th,
    table th {
      background: #f8fafc;
    }
    .question-html table p,
    .question-html table div,
    .question-html table figure {
      margin: 0 !important;
    }
    .math-placeholder {
      display: inline;
      white-space: normal;
    }
    .math-placeholder > * {
      display: inline !important;
    }
    mjx-container {
      display: inline-block !important;
      max-width: 100%;
      overflow: visible;
      margin: 0 0.06em;
      vertical-align: middle;
    }
    mjx-container[display="true"] {
      display: inline-block !important;
      margin: 0 0.06em !important;
    }
    .question-html .math-block mjx-container,
    .question-html .math-stack mjx-container {
      display: inline-block !important;
      margin: 0;
    }
  </style>
  <script>
    window.MathJax = {
      options: {
        renderActions: { addMenu: [] },
      },
      startup: {
        typeset: false,
      },
    };
    function measureHeight() {
      const body = document.body;
      const html = document.documentElement;
      const height = Math.max(
        body.scrollHeight,
        body.offsetHeight,
        html.clientHeight,
        html.scrollHeight,
        html.offsetHeight,
      );
      HeightObserver.postMessage(String(height));
    }
    function cleanupHtml() {
      const root = document.querySelector('.question-html, .inline-root');
      if (!root) {
        return;
      }

      root.querySelectorAll('span, p, div').forEach((node) => {
        if (node.querySelector('img, table, math, mjx-container, figure, svg')) {
          return;
        }
        const text = (node.textContent || '').replace(/\\u00a0/g, '').trim();
        if (!text) {
          node.remove();
        }
      });

      root.querySelectorAll('figure.table').forEach((figure) => {
        figure.classList.add('table-wrap');
      });

      root.querySelectorAll('table').forEach((table) => {
        if (table.parentElement && table.parentElement.classList.contains('table-wrap')) {
          return;
        }
        const wrapper = document.createElement('div');
        wrapper.className = 'table-wrap';
        table.parentNode.insertBefore(wrapper, table);
        wrapper.appendChild(table);
      });

      root.querySelectorAll('p').forEach((paragraph) => {
        if (paragraph.closest('table')) {
          paragraph.style.margin = '0';
        }
      });
      if (root.classList.contains('inline-root')) {
        root.querySelectorAll('br').forEach((br) => br.remove());
      }
    }
    window.addEventListener('load', async function () {
      try {
        cleanupHtml();
        if (window.MathJax && window.MathJax.typesetPromise) {
          await window.MathJax.typesetPromise();
        }
      } catch (e) {}
      cleanupHtml();
      measureHeight();
      setTimeout(measureHeight, 120);
      setTimeout(measureHeight, 360);
      setTimeout(measureHeight, 800);
    });
  </script>
  <script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/mml-chtml.js"></script>
</head>
<body>
  <div class="$rootClass">${widget.html}</div>
</body>
</html>
''';
  }

  String _cssColor(Color color) {
    return 'rgba(${(color.r * 255).round()}, ${(color.g * 255).round()}, ${(color.b * 255).round()}, ${color.a})';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: IgnorePointer(
        ignoring: !widget.interactive,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _CalculatorDialog extends StatefulWidget {
  const _CalculatorDialog();

  @override
  State<_CalculatorDialog> createState() => _CalculatorDialogState();
}

class _CalculatorDialogState extends State<_CalculatorDialog> {
  String _display = '0';
  double? _leftValue;
  String? _operator;
  bool _replaceDisplay = false;

  void _inputDigit(String digit) {
    setState(() {
      if (_replaceDisplay || _display == '0') {
        _display = digit;
      } else {
        _display += digit;
      }
      _replaceDisplay = false;
    });
  }

  void _inputDot() {
    setState(() {
      if (_replaceDisplay) {
        _display = '0.';
        _replaceDisplay = false;
        return;
      }
      if (!_display.contains('.')) {
        _display += '.';
      }
    });
  }

  void _setOperator(String op) {
    final current = double.tryParse(_display) ?? 0;
    setState(() {
      if (_leftValue == null) {
        _leftValue = current;
      } else if (_operator != null) {
        _leftValue = _apply(_leftValue!, current, _operator!);
        _display = _format(_leftValue!);
      }
      _operator = op;
      _replaceDisplay = true;
    });
  }

  void _equals() {
    if (_operator == null || _leftValue == null) {
      return;
    }
    final right = double.tryParse(_display) ?? 0;
    setState(() {
      final result = _apply(_leftValue!, right, _operator!);
      _display = _format(result);
      _leftValue = null;
      _operator = null;
      _replaceDisplay = true;
    });
  }

  void _clear() {
    setState(() {
      _display = '0';
      _leftValue = null;
      _operator = null;
      _replaceDisplay = false;
    });
  }

  void _clearEntry() {
    setState(() {
      _display = '0';
      _replaceDisplay = false;
    });
  }

  void _deleteLast() {
    setState(() {
      if (_replaceDisplay) {
        _display = '0';
        _replaceDisplay = false;
        return;
      }
      if (_display.length <= 1 ||
          (_display.length == 2 && _display.startsWith('-'))) {
        _display = '0';
        return;
      }
      _display = _display.substring(0, _display.length - 1);
    });
  }

  void _toggleSign() {
    setState(() {
      if (_display == '0') {
        return;
      }
      _display = _display.startsWith('-')
          ? _display.substring(1)
          : '-$_display';
    });
  }

  void _applyPercent() {
    final current = double.tryParse(_display) ?? 0;
    setState(() {
      _display = _format(current / 100);
      _replaceDisplay = true;
    });
  }

  void _setPi() {
    setState(() {
      _display = _format(math.pi);
      _replaceDisplay = true;
    });
  }

  void _applyUnary(String operation) {
    final current = double.tryParse(_display) ?? 0;
    double result = current;
    switch (operation) {
      case 'sqrt':
        result = current < 0 ? 0 : math.sqrt(current);
        break;
      case 'square':
        result = current * current;
        break;
      case 'inverse':
        result = current == 0 ? 0 : 1 / current;
        break;
      default:
        result = current;
    }

    setState(() {
      _display = _format(result);
      _replaceDisplay = true;
    });
  }

  double _apply(double left, double right, String op) {
    switch (op) {
      case '+':
        return left + right;
      case '-':
        return left - right;
      case '×':
        return left * right;
      case '÷':
        if (right == 0) return 0;
        return left / right;
      default:
        return right;
    }
  }

  String _format(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value
        .toStringAsFixed(6)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Widget _button({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
    IconData? icon,
  }) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: filled
            ? QuizDetailPalette.primary
            : const Color(0xFFF1F5F9),
        foregroundColor: filled ? Colors.white : QuizDetailPalette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size.fromHeight(30),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      ),
      child: icon != null
          ? Icon(icon, size: 12)
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.height < 720 || viewport.width < 420;
    final tiny = viewport.height < 520 || viewport.width < 360;
    final maxDialogWidth = viewport.width < 700
        ? math.min(viewport.width * 0.88, 400.0)
        : 460.0;
    final maxDialogHeight = viewport.height * 0.76;
    final historyLabel = _leftValue == null || _operator == null
        ? ''
        : '${_format(_leftValue!)} $_operator';

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 18,
        vertical: compact ? 10 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(compact ? 6 : 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calculator',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 14 : 16,
                          color: QuizDetailPalette.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 6 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: QuizDetailPalette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        historyLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 10 : 12,
                          color: QuizDetailPalette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        _display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 22,
                          fontWeight: FontWeight.w800,
                          color: QuizDetailPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 8 : 10),
                GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: compact ? 3 : 5,
                  crossAxisSpacing: compact ? 3 : 5,
                  childAspectRatio: compact ? 1.42 : 1.22,
                  children: [
                    _button(label: 'C', onTap: _clear),
                    _button(label: 'CE', onTap: _clearEntry),
                    _button(
                      label: '',
                      icon: Icons.backspace_outlined,
                      onTap: _deleteLast,
                    ),
                    _button(label: '±', onTap: _toggleSign),
                    _button(label: '%', onTap: _applyPercent),
                    _button(label: '7', onTap: () => _inputDigit('7')),
                    _button(label: '8', onTap: () => _inputDigit('8')),
                    _button(label: '9', onTap: () => _inputDigit('9')),
                    _button(
                      label: '÷',
                      onTap: () => _setOperator('÷'),
                      filled: true,
                    ),
                    _button(label: '√', onTap: () => _applyUnary('sqrt')),
                    _button(label: '4', onTap: () => _inputDigit('4')),
                    _button(label: '5', onTap: () => _inputDigit('5')),
                    _button(label: '6', onTap: () => _inputDigit('6')),
                    _button(
                      label: '×',
                      onTap: () => _setOperator('×'),
                      filled: true,
                    ),
                    _button(label: 'x²', onTap: () => _applyUnary('square')),
                    _button(label: '1', onTap: () => _inputDigit('1')),
                    _button(label: '2', onTap: () => _inputDigit('2')),
                    _button(label: '3', onTap: () => _inputDigit('3')),
                    _button(
                      label: '−',
                      onTap: () => _setOperator('-'),
                      filled: true,
                    ),
                    _button(label: '1/x', onTap: () => _applyUnary('inverse')),
                    _button(label: '0', onTap: () => _inputDigit('0')),
                    _button(label: '.', onTap: _inputDot),
                    _button(label: 'π', onTap: _setPi),
                    _button(
                      label: '+',
                      onTap: () => _setOperator('+'),
                      filled: true,
                    ),
                    _button(label: '=', onTap: _equals, filled: true),
                  ],
                ),
                if (!tiny) ...[
                  SizedBox(height: compact ? 4 : 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hỗ trợ: +  −  ×  ÷  %, đổi dấu, căn bậc hai, bình phương, nghịch đảo, π',
                      style: TextStyle(
                        color: QuizDetailPalette.textSecondary,
                        fontSize: compact ? 9 : 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionColorState {
  const _OptionColorState({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.contentColor,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color contentColor;
}

enum _ContentChunkType { text, mathText, imageUrl, imageBytes }

class _ContentChunk {
  const _ContentChunk._({required this.type, required this.value, this.bytes});

  final _ContentChunkType type;
  final String value;
  final Uint8List? bytes;

  factory _ContentChunk.text(String value) {
    return _ContentChunk._(type: _ContentChunkType.text, value: value);
  }

  factory _ContentChunk.mathText(String value) {
    return _ContentChunk._(type: _ContentChunkType.mathText, value: value);
  }

  factory _ContentChunk.imageUrl(String value) {
    return _ContentChunk._(type: _ContentChunkType.imageUrl, value: value);
  }

  factory _ContentChunk.imageBytes(Uint8List bytes) {
    return _ContentChunk._(
      type: _ContentChunkType.imageBytes,
      value: '',
      bytes: bytes,
    );
  }
}

class _BreakScreen extends StatelessWidget {
  const _BreakScreen({
    required this.examName,
    required this.breakSeconds,
    required this.userName,
    required this.onResumeNow,
  });

  final String examName;
  final int breakSeconds;
  final String userName;
  final VoidCallback onResumeNow;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 560;
    final timerText = _formatBreakSeconds(breakSeconds);

    return Container(
      color: const Color(0xFF333333),
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 18,
          compact ? 10 : 16,
          compact ? 12 : 18,
          compact ? 10 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              examName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 18 : 26,
                              vertical: compact ? 14 : 20,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Remaining Break Time',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 14 : 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  timerText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: compact ? 44 : 72,
                                    fontWeight: FontWeight.w900,
                                    height: 0.95,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: onResumeNow,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF324DC7),
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 18 : 28,
                                vertical: compact ? 10 : 14,
                              ),
                            ),
                            child: Text(
                              'Resume Testing',
                              style: TextStyle(
                                fontSize: compact ? 13 : 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    color: Colors.white24,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: const Color(0xFFBFBFBF),
                            fontSize: compact ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Practice Test Break',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 18 : 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "You can resume this practice test as soon as you're ready to move on.",
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Take a Break: Do Not Close Your Device',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 18 : 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'After the break, a Resume Testing button is available. Keep this screen open.',
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Follow these rules during the break:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '1. Do not disturb students who are still testing.',
                              ),
                              const Text(
                                '2. Do not exit the app or close your device.',
                              ),
                              const Text(
                                '3. Do not access phone, notes, or internet.',
                              ),
                              const Text(
                                '4. Do not eat or drink near testing device.',
                              ),
                              const Text('5. Do not discuss the exam content.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              userName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBreakSeconds(int seconds) {
  final mm = (seconds ~/ 60).toString();
  final ss = (seconds % 60).toString().padLeft(2, '0');
  return '$mm:$ss';
}

class _RoomModuleBlock {
  const _RoomModuleBlock({
    required this.name,
    required this.key,
    required this.questions,
    required this.durationSeconds,
  });

  final String name;
  final String key;
  final List<QuizQuestion> questions;
  final int durationSeconds;
}

class _ExamLoadingScreen extends StatefulWidget {
  const _ExamLoadingScreen();

  @override
  State<_ExamLoadingScreen> createState() => _ExamLoadingScreenState();
}

class _ExamLoadingScreenState extends State<_ExamLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.08),
          radius: 0.95,
          colors: [Color(0xFFFDFDFF), Color(0xFFF1F4FF), Color(0xFFE6ECFB)],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value * math.pi * 2;
            final tiltX = math.sin(t) * 0.28;
            final tiltY = math.cos(t * 0.85) * 0.34;
            final ringRotation = _controller.value * math.pi * 2;
            final glowScale = 1 + (math.sin(t * 1.4) * 0.045);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: glowScale,
                        child: Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7768FF).withValues(alpha: 0.24),
                                const Color(0xFF7768FF).withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: ringRotation,
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: const _OrbitRingPainter(
                            primary: Color(0xFF4F1BDB),
                            secondary: Color(0xFF6D7BFF),
                            accent: Color(0xFFFFA345),
                          ),
                        ),
                      ),
                      Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0016)
                          ..rotateX(tiltX)
                          ..rotateY(tiltY),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 154,
                              height: 154,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF755BFF),
                                    Color(0xFF4F1BDB),
                                    Color(0xFF32139F),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x4032149F),
                                    blurRadius: 34,
                                    offset: Offset(0, 22),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 20,
                              left: 34,
                              right: 34,
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.68),
                                      Colors.white.withValues(alpha: 0.06),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 116,
                              height: 116,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF3D17CF),
                                    Color(0xFF2A0D86),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: ringRotation * -1.4,
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 52,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 40,
                        child: Transform.scale(
                          scaleX: 1.15 + (math.sin(t) * 0.06),
                          scaleY: 1.0,
                          child: Container(
                            width: 156,
                            height: 24,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: RadialGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.18),
                                  Colors.black.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Đang chuyển module...',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng chờ một chút để tải phần tiếp theo.',
                  style: TextStyle(
                    color: QuizDetailPalette.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final mainRect = Rect.fromCircle(center: center, radius: 82);
    final outerRect = Rect.fromCircle(center: center, radius: 98);
    final innerRect = Rect.fromCircle(center: center, radius: 66);

    _drawArc(
      canvas,
      rect: mainRect,
      strokeWidth: 28,
      startAngle: -2.5,
      sweep: 3.55,
      color: primary,
    );
    _drawArc(
      canvas,
      rect: outerRect,
      strokeWidth: 9,
      startAngle: -2.35,
      sweep: 4.45,
      color: secondary,
    );
    _drawArc(
      canvas,
      rect: innerRect,
      strokeWidth: 9,
      startAngle: -1.9,
      sweep: 3.15,
      color: const Color(0xFF3D17CF),
    );

    _drawArc(
      canvas,
      rect: Rect.fromCircle(center: center, radius: 104),
      strokeWidth: 3,
      startAngle: -0.12,
      sweep: 1.1,
      color: const Color(0xFF1E1E1E),
    );
    _drawArc(
      canvas,
      rect: outerRect,
      strokeWidth: 8,
      startAngle: 0.78,
      sweep: 0.28,
      color: accent,
    );
  }

  void _drawArc(
    Canvas canvas, {
    required Rect rect,
    required double strokeWidth,
    required double sweep,
    required Color color,
    required double startAngle,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) => false;
}
