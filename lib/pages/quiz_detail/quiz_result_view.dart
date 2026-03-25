import 'dart:convert';
import 'dart:typed_data';

import 'package:edly/core/config/api_config.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart' as xml;

class QuizResultView extends StatefulWidget {
  const QuizResultView({
    super.key,
    required this.result,
    required this.quizName,
    required this.questionCount,
  });

  final QuizResultData result;
  final String quizName;
  final int questionCount;

  @override
  State<QuizResultView> createState() => _QuizResultViewState();
}

class _QuizResultViewState extends State<QuizResultView> {
  final Map<String, GlobalKey> _questionKeys = {};
  final Map<String, bool> _transcriptOpen = {};
  final ScrollController _scrollController = ScrollController();
  String? _selectedQuestionId;

  bool get _isExam =>
      widget.result.submissionType == 'exam' || widget.result.type == 'module';

  List<QuizQuestion> get _displayQuestions {
    final questions = widget.result.questions;
    if (!_isExam ||
        !widget.result.isSingleModule ||
        widget.result.selectedModule.isEmpty) {
      return questions;
    }

    return questions
        .where(
          (item) => item.effectiveModuleName == widget.result.selectedModule,
        )
        .toList();
  }

  List<_IndexedQuestion> get _indexedQuestions {
    final questions = _displayQuestions;
    return List<_IndexedQuestion>.generate(
      questions.length,
      (index) => _IndexedQuestion(
        displayNumber: index + 1,
        question: questions[index],
      ),
    );
  }

  Map<String, Map<String, dynamic>> get _answersByQuestionId {
    final map = <String, Map<String, dynamic>>{};
    for (final answer in widget.result.answers) {
      final id = _asText(answer['question_id']);
      if (id.isNotEmpty) {
        map[id] = answer;
      }
    }
    return map;
  }

  int get _totalQuestions {
    if (_displayQuestions.isNotEmpty) {
      return _displayQuestions.length;
    }
    if (widget.result.quizQuestionCount > 0) {
      return widget.result.quizQuestionCount;
    }
    if (widget.questionCount > 0) {
      return widget.questionCount;
    }
    return widget.result.answers.length;
  }

  int get _answeredCount {
    if (_displayQuestions.isNotEmpty) {
      return _displayQuestions
          .where(
            (item) =>
                _statusOf(item, _answersByQuestionId) !=
                _AnswerStatus.unanswered,
          )
          .length;
    }

    return widget.result.answers.where((item) {
      final selected = _asText(item['selected_option']);
      final text = _asText(item['answer_text']);
      final raw = _asText(item['user_answer']);
      return selected.isNotEmpty || text.isNotEmpty || raw.isNotEmpty;
    }).length;
  }

  int get _correctCount {
    if (_displayQuestions.isNotEmpty) {
      return _displayQuestions
          .where(
            (item) =>
                _statusOf(item, _answersByQuestionId) == _AnswerStatus.correct,
          )
          .length;
    }

    return widget.result.answers
        .where((item) => item['is_correct'] == true)
        .length;
  }

  int get _incorrectCount {
    if (_displayQuestions.isNotEmpty) {
      return _displayQuestions
          .where(
            (item) =>
                _statusOf(item, _answersByQuestionId) ==
                _AnswerStatus.incorrect,
          )
          .length;
    }

    return widget.result.answers.where((item) {
      final selected = _asText(item['selected_option']);
      final text = _asText(item['answer_text']);
      final raw = _asText(item['user_answer']);
      final hasAnswer =
          selected.isNotEmpty || text.isNotEmpty || raw.isNotEmpty;
      return hasAnswer && item['is_correct'] != true;
    }).length;
  }

  int get _unansweredCount =>
      (_totalQuestions - _answeredCount).clamp(0, 100000);

  double get _completionPercent {
    if (_totalQuestions <= 0) {
      return 0;
    }
    return (_answeredCount / _totalQuestions) * 100;
  }

  int get _finalScore {
    if (widget.result.score.totalScore > 0) {
      return widget.result.score.totalScore;
    }

    if (widget.result.isSingleModule &&
        widget.result.selectedModule.isNotEmpty) {
      final key = _moduleKeyOf(widget.result.selectedModule);
      final raw = key == null ? null : widget.result.score.rawModules[key];
      if (raw != null && raw.score > 0) {
        return raw.score;
      }
    }

    return widget.result.score.inferredTotalScore;
  }

  int get _finalScoreMax {
    if (!_isExam) {
      return _totalQuestions;
    }
    if (widget.result.isSingleModule) {
      return 400;
    }
    return 1600;
  }

  int? get _usedSeconds {
    final moduleTimes = widget.result.moduleTimes;
    if (_isExam && moduleTimes.isNotEmpty) {
      const durations = <String, int>{
        'rw1': 32 * 60,
        'rw2': 32 * 60,
        'm1': 35 * 60,
        'm2': 35 * 60,
      };
      var used = 0;
      for (final entry in durations.entries) {
        final leftRaw = moduleTimes[entry.key];
        final left = leftRaw == null
            ? entry.value
            : leftRaw.clamp(0, entry.value).toInt();
        used += entry.value - left;
      }
      return used;
    }

    if (widget.result.secondLeft > 0 || _answeredCount > 0) {
      return widget.result.secondLeft;
    }
    return null;
  }

  int? get _totalAvailableSeconds {
    if (!_isExam) {
      return null;
    }

    if (widget.result.isSingleModule &&
        widget.result.selectedModule.isNotEmpty) {
      final key = _moduleKeyOf(widget.result.selectedModule);
      switch (key) {
        case 'rw1':
        case 'rw2':
          return 32 * 60;
        case 'm1':
        case 'm2':
          return 35 * 60;
      }
    }

    final modules = _orderedModuleNames;
    final hasClassicOrder = _satModuleOrder.every(modules.contains);
    if (hasClassicOrder) {
      return (32 * 60 * 2) + (35 * 60 * 2);
    }
    return null;
  }

  int get _remainingSeconds {
    final total = _totalAvailableSeconds;
    final used = _usedSeconds;
    if (total == null || used == null) {
      return 0;
    }
    return (total - used).clamp(0, total);
  }

  int get _averageSecondsPerQuestion {
    final used = _usedSeconds;
    if (used == null || _answeredCount <= 0) {
      return 0;
    }
    return (used / _answeredCount).round();
  }

  String get _effectiveQuizName {
    if (widget.result.quizName.isNotEmpty) {
      return widget.result.quizName;
    }
    return widget.quizName;
  }

  List<String> get _orderedModuleNames {
    if (widget.result.isSingleModule &&
        widget.result.selectedModule.isNotEmpty) {
      return [widget.result.selectedModule];
    }

    final unique = <String>[];
    for (final question in _displayQuestions) {
      final moduleName = question.effectiveModuleName.isEmpty
          ? 'Quiz'
          : question.effectiveModuleName;
      if (!unique.contains(moduleName)) {
        unique.add(moduleName);
      }
    }

    final hasClassicOrder = _satModuleOrder.every(unique.contains);
    if (hasClassicOrder) {
      return [..._satModuleOrder];
    }
    return unique.isEmpty ? const ['Quiz'] : unique;
  }

  Map<String, List<_IndexedQuestion>> get _questionsByModule {
    final grouped = <String, List<_IndexedQuestion>>{};
    for (final item in _indexedQuestions) {
      final moduleName = item.question.effectiveModuleName.isEmpty
          ? 'Quiz'
          : item.question.effectiveModuleName;
      grouped.putIfAbsent(moduleName, () => <_IndexedQuestion>[]).add(item);
    }

    final ordered = <String, List<_IndexedQuestion>>{};
    for (final name in _orderedModuleNames) {
      if (grouped.containsKey(name)) {
        ordered[name] = grouped[name]!;
      }
    }
    for (final entry in grouped.entries) {
      ordered.putIfAbsent(entry.key, () => entry.value);
    }
    return ordered;
  }

  List<_BreakdownBucket> get _questionTypeBreakdownRw {
    return _buildQuestionTypeBreakdown('rw');
  }

  List<_BreakdownBucket> get _questionTypeBreakdownMath {
    return _buildQuestionTypeBreakdown('math');
  }

  bool get _hasQuestionTypeBreakdown =>
      _questionTypeBreakdownRw.isNotEmpty ||
      _questionTypeBreakdownMath.isNotEmpty;

  List<_AiInsight> get _aiInsights => [
    const _AiInsight(
      title: 'Điểm yếu chính',
      body:
          'Hãy tập trung xem lại các câu sai và các câu bỏ trống để xác định đúng nhóm kỹ năng bạn đang hụt. Bắt đầu từ module có tỷ lệ chính xác thấp hơn để cải thiện nhanh hơn.',
    ),
    const _AiInsight(
      title: 'Quản lý thời gian',
      body:
          'So sánh thời gian trung bình mỗi câu với số câu chưa làm để cân chỉnh nhịp độ. Nếu còn bỏ trống nhiều câu, ưu tiên rèn chiến lược làm nhanh ở các câu nền tảng.',
    ),
    const _AiInsight(
      title: 'Tiềm năng cải thiện',
      body:
          'Bạn có thể nâng điểm rõ rệt nếu tăng độ chính xác ở các câu hiện đang sai hoặc bỏ trống. Hãy luyện lại theo từng module và đối chiếu lời giải chi tiết ngay bên dưới.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final questions = _displayQuestions;
    if (questions.isNotEmpty) {
      _selectedQuestionId = questions.first.id;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectQuestion(QuizQuestion question) {
    setState(() {
      _selectedQuestionId = question.id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToQuestion(question.id);
    });
  }

  Future<void> _scrollToQuestion(String questionId) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final context = _questionKeys[questionId]?.currentContext;
    if (context == null) {
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null) {
      return;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final targetOffset =
        viewport.getOffsetToReveal(renderObject, 0.0).offset - 18;
    final position = _scrollController.position;
    final clampedOffset = targetOffset.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleTranscript(QuizQuestion question) {
    final id = question.id;
    setState(() {
      _transcriptOpen[id] = !(_transcriptOpen[id] ?? false);
    });
  }

  List<_BreakdownBucket> _buildQuestionTypeBreakdown(String area) {
    final counts = <String, int>{};
    for (final question in _displayQuestions) {
      if (_resolveQuestionArea(question) != area) {
        continue;
      }
      final label = _normalizeDomainLabel(question.domain);
      if (label == null) {
        continue;
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final items =
        counts.entries
            .map(
              (entry) => _BreakdownBucket(name: entry.key, count: entry.value),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final isWide = viewport.width >= 1080;
    final headerDateText = widget.result.createdAt == null
        ? ''
        : DateFormat('HH:mm • dd/MM/yyyy').format(widget.result.createdAt!);
    final headerTestTimeText = _usedSeconds == null
        ? ''
        : _formatReadableDuration(_usedSeconds!);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            Container(
              color: const Color(0xFF472A3E),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 24 : 16,
                      24,
                      isWide ? 24 : 16,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kết quả: $_effectiveQuizName',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: isWide ? 28 : 22,
                            height: 1.25,
                          ),
                        ),
                        if (headerDateText.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hoàn thành lúc $headerDateText',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (headerTestTimeText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Test Time:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                headerTestTimeText,
                                style: const TextStyle(
                                  color: Color(0xFFD0CBD1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 16 : 12,
                    16,
                    isWide ? 16 : 12,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF12B76A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text(
                        'Học tiếp',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 16 : 12,
                    18,
                    isWide ? 16 : 12,
                    24,
                  ),
                  child: Column(
                    children: [
                      if (_isExam)
                        _buildExamSummary(isWide: isWide)
                      else
                        _buildExerciseSummary(isWide: isWide),
                      const SizedBox(height: 24),
                      _buildAiSection(),
                      if (_indexedQuestions.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildReviewSection(isWide: isWide),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSummary({required bool isWide}) {
    final left = _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Tổng quan kết quả:',
                style: TextStyle(
                  color: QuizDetailPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: _DonutChart(
              correct: _correctCount,
              incorrect: _incorrectCount,
              unanswered: _unansweredCount,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 10,
            children: [
              _LegendDot(
                color: const Color(0xFF22C55E),
                text: '$_correctCount Đúng',
              ),
              _LegendDot(
                color: const Color(0xFFFF1F5B),
                text: '$_incorrectCount Sai',
              ),
              _LegendDot(
                color: const Color(0xFF98A2B3),
                text: '$_unansweredCount Chưa làm',
              ),
            ],
          ),
        ],
      ),
    );

    final right = _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Final Score:',
                style: TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$_finalScore',
                style: const TextStyle(
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w900,
                  fontSize: 34,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $_finalScoreMax',
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_isSingleArea('math'))
            _ScoreAreaPanel(
              label: 'Reading and Writing',
              totalScore: widget.result.score.rwScore,
              firstModuleScore: widget.result.score.rawModules['rw1']?.score,
              secondModuleScore: widget.result.score.rawModules['rw2']?.score,
              progress: ((widget.result.score.rwScore) / 800).clamp(0.0, 1.0),
              color: _progressColor((widget.result.score.rwScore / 800) * 100),
            ),
          if (!_isSingleArea('math') && !_isSingleArea('rw'))
            const SizedBox(height: 18),
          if (!_isSingleArea('rw'))
            _ScoreAreaPanel(
              label: 'Math',
              totalScore: widget.result.score.mathScore,
              firstModuleScore: widget.result.score.rawModules['m1']?.score,
              secondModuleScore: widget.result.score.rawModules['m2']?.score,
              progress: ((widget.result.score.mathScore) / 800).clamp(0.0, 1.0),
              color: _progressColor(
                (widget.result.score.mathScore / 800) * 100,
              ),
            ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Tốc độ làm bài:',
                style: TextStyle(
                  color: QuizDetailPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _MetricPanel(
                label: 'Thời gian trung bình',
                value: _formatClock(_averageSecondsPerQuestion),
                suffix: '/ câu',
                progress: _usedSeconds == null || _totalAvailableSeconds == null
                    ? null
                    : (_averageSecondsPerQuestion /
                              ((_totalAvailableSeconds! /
                                  (_totalQuestions == 0
                                      ? 1
                                      : _totalQuestions))))
                          .clamp(0.0, 1.0),
                progressColor: const Color(0xFF8B5CF6),
              ),
              _MetricPanel(
                label: 'Số câu đã làm',
                value: '$_answeredCount',
                suffix: '/ $_totalQuestions',
                progress: (_completionPercent / 100).clamp(0.0, 1.0),
                progressColor: const Color(0xFF4F46E5),
              ),
              _MetricPanel(
                label: 'Thời gian còn lại',
                value: _formatClock(_remainingSeconds),
                progress: _totalAvailableSeconds == null
                    ? null
                    : (_remainingSeconds / _totalAvailableSeconds!).clamp(
                        0.0,
                        1.0,
                      ),
                progressColor: const Color(0xFF64748B),
              ),
            ],
          ),
          if (_hasQuestionTypeBreakdown) ...[
            const SizedBox(height: 22),
            const Divider(height: 1),
            const SizedBox(height: 20),
            const Text(
              'Question Type (Skills)',
              style: TextStyle(
                color: QuizDetailPalette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Here is a breakdown of the exam questions in both sections.',
              style: TextStyle(color: Color(0xFF667085), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: [
                if (!_isSingleArea('math'))
                  _BreakdownPanel(
                    title: 'Reading and Writing',
                    items: _questionTypeBreakdownRw,
                  ),
                if (!_isSingleArea('rw'))
                  _BreakdownPanel(
                    title: 'Math',
                    items: _questionTypeBreakdownMath,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFACC15)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFB45309)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Độ chính xác của bạn khá tốt, tuy nhiên áp lực thời gian tăng lên ở các module khó hơn. Hãy tiếp tục luyện đều để giữ tốc độ khi vào các phần adaptive.',
                    style: TextStyle(color: Color(0xFF475467), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 24),
          Expanded(flex: 2, child: right),
        ],
      );
    }

    return Column(children: [left, const SizedBox(height: 18), right]);
  }

  Widget _buildExerciseSummary({required bool isWide}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ResultSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kết quả của bạn',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '$_finalScore',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w900,
                          fontSize: 56,
                        ),
                      ),
                      Text(
                        '/ $_totalQuestions câu',
                        style: const TextStyle(
                          color: Color(0xFF98A2B3),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _ResultCountRow(
                  label: 'Đúng',
                  value: _correctCount,
                  background: const Color(0xFFECFDF3),
                  foreground: const Color(0xFF16A34A),
                ),
                const SizedBox(height: 10),
                _ResultCountRow(
                  label: 'Sai',
                  value: _incorrectCount,
                  background: const Color(0xFFFEF2F2),
                  foreground: const Color(0xFFDC2626),
                ),
                const SizedBox(height: 10),
                _ResultCountRow(
                  label: 'Chưa làm',
                  value: _unansweredCount,
                  background: const Color(0xFFF8FAFC),
                  foreground: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (isWide) const SizedBox(width: 24),
        if (isWide)
          Expanded(
            flex: 2,
            child: _ResultSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thống kê',
                    style: TextStyle(
                      color: QuizDetailPalette.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MetricPanel(
                    label: 'Độ chính xác',
                    value: _answeredCount == 0
                        ? '0%'
                        : '${((_correctCount / _answeredCount) * 100).round()}%',
                    progress: _answeredCount == 0
                        ? 0
                        : _correctCount / _answeredCount,
                    progressColor: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 18),
                  _MetricPanel(
                    label: 'Hoàn thành',
                    value: '${_completionPercent.round()}%',
                    progress: (_completionPercent / 100).clamp(0.0, 1.0),
                    progressColor: const Color(0xFF16A34A),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAiSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0D4CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFFE4DE),
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF676F7E),
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhận xét từ AI',
                    style: TextStyle(
                      color: QuizDetailPalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Phân tích dựa trên kết quả làm bài của bạn',
                    style: TextStyle(color: Color(0xFF676F7E), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _aiInsights
                .map(
                  (item) => SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEFEA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.track_changes_outlined,
                              color: Color(0xFF676F7E),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: QuizDetailPalette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.body,
                            style: const TextStyle(
                              color: Color(0xFF676F7E),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection({required bool isWide}) {
    final details = Column(
      children: _indexedQuestions.map((indexed) {
        final question = indexed.question;
        final key = _questionKeys.putIfAbsent(question.id, GlobalKey.new);
        return Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 20),
          child: _QuestionReviewCard(
            indexedQuestion: indexed,
            question: question,
            answer: _answersByQuestionId[question.id],
            isSelected: _selectedQuestionId == question.id,
            isTranscriptOpen: _transcriptOpen[question.id] == true,
            onToggleTranscript: _hasTranscript(question)
                ? () => _toggleTranscript(question)
                : null,
            onTap: () => _selectQuestion(question),
          ),
        );
      }).toList(),
    );

    final board = _QuestionBoardPanel(
      selectedQuestionId: _selectedQuestionId,
      modules: _questionsByModule,
      answersByQuestionId: _answersByQuestionId,
      onSelectQuestion: _selectQuestion,
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: details),
          const SizedBox(width: 24),
          SizedBox(width: 360, child: board),
        ],
      );
    }

    return Column(children: [board, const SizedBox(height: 20), details]);
  }

  bool _isSingleArea(String area) {
    if (!widget.result.isSingleModule || widget.result.selectedModule.isEmpty) {
      return false;
    }
    final key = widget.result.selectedModule.toLowerCase();
    if (area == 'rw') {
      return key.contains('reading') || key.contains('writing');
    }
    if (area == 'math') {
      return key.contains('math');
    }
    return false;
  }
}

class _QuestionReviewCard extends StatelessWidget {
  const _QuestionReviewCard({
    required this.indexedQuestion,
    required this.question,
    required this.answer,
    required this.isSelected,
    required this.isTranscriptOpen,
    required this.onToggleTranscript,
    required this.onTap,
  });

  final _IndexedQuestion indexedQuestion;
  final QuizQuestion question;
  final Map<String, dynamic>? answer;
  final bool isSelected;
  final bool isTranscriptOpen;
  final VoidCallback? onToggleTranscript;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answersMap = answer == null
        ? const <String, Map<String, dynamic>>{}
        : <String, Map<String, dynamic>>{question.id: answer!};
    final status = _statusOf(question, answersMap);
    final badge = _badgeForStatus(status);
    final statusMessage = _statusMessageFor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A2563EB),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconForStatus(status),
                            size: 18,
                            color: badge.foreground,
                          ),
                        ),
                        Text(
                          'Question ${indexedQuestion.displayNumber}',
                          style: const TextStyle(
                            color: QuizDetailPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badge.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge.label,
                            style: TextStyle(
                              color: badge.foreground,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '📚 ${question.effectiveModuleName.isEmpty ? 'Quiz' : question.effectiveModuleName}',
                      style: const TextStyle(
                        color: Color(0xFF324DC7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0D5DD)),
                ),
                child: _QuizContentView(
                  question: question,
                  raw: question.content.isNotEmpty
                      ? question.content
                      : question.title,
                  style: const TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                  maxImageHeight: 180,
                ),
              ),
              const SizedBox(height: 18),
              if (!_isEssayQuestion(question)) ...[
                const Text(
                  'Các đáp án:',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                ...List<Widget>.generate(question.options.length, (index) {
                  final option = question.options[index];
                  final optionState = _optionState(question, option, answer);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: optionState.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: optionState.border,
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_optionLabel(index)}.',
                            style: TextStyle(
                              color: optionState.labelColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _QuizContentView(
                              question: question,
                              option: option,
                              raw: option.content,
                              style: TextStyle(
                                color: optionState.contentColor,
                                fontSize: 16,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                              maxImageHeight: 120,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (option.isCorrect)
                            const _OptionFlag(
                              icon: Icons.check_circle_rounded,
                              label: 'Đáp án đúng',
                              color: Color(0xFF10B981),
                            )
                          else if (_isUserSelectedOption(answer, option))
                            const _OptionFlag(
                              icon: Icons.cancel_rounded,
                              label: 'Bạn chọn',
                              color: Color(0xFFFF1F5B),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ] else ...[
                const Text(
                  'Câu trả lời của bạn:',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bài làm của bạn:',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userAnswerOf(question, answer),
                        style: TextStyle(
                          color: _userAnswerOf(question, answer) == '-'
                              ? const Color(0xFF94A3B8)
                              : QuizDetailPalette.textPrimary,
                          fontStyle: _userAnswerOf(question, answer) == '-'
                              ? FontStyle.italic
                              : FontStyle.normal,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusMessage.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: statusMessage.border),
                ),
                child: Text(
                  statusMessage.text,
                  style: TextStyle(
                    color: statusMessage.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (question.explanation.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC8DFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Lời giải chi tiết',
                        style: TextStyle(
                          color: Color(0xFF60A5FA),
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _QuizContentView(
                        question: question,
                        raw: question.explanation,
                        style: const TextStyle(
                          color: QuizDetailPalette.textPrimary,
                          fontSize: 16,
                          height: 1.6,
                        ),
                        maxImageHeight: 150,
                      ),
                      if (_hasTranscript(question)) ...[
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: onToggleTranscript,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTranscriptOpen
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: const Color(0xFF4F46E5),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Transcript',
                                  style: TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isTranscriptOpen) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: _QuizContentView(
                              question: question,
                              raw: question.transcript,
                              style: const TextStyle(
                                color: QuizDetailPalette.textPrimary,
                                fontSize: 14,
                                height: 1.55,
                              ),
                              maxImageHeight: 120,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionBoardPanel extends StatelessWidget {
  const _QuestionBoardPanel({
    required this.selectedQuestionId,
    required this.modules,
    required this.answersByQuestionId,
    required this.onSelectQuestion,
  });

  final String? selectedQuestionId;
  final Map<String, List<_IndexedQuestion>> modules;
  final Map<String, Map<String, dynamic>> answersByQuestionId;
  final ValueChanged<QuizQuestion> onSelectQuestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.grid_view_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Text(
                  'Danh sách câu hỏi',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Chọn câu hỏi để xem chi tiết',
              style: TextStyle(color: Color(0xFF667085), fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...modules.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Color(0xFF475467),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: entry.value.map((item) {
                        final status = _statusOf(
                          item.question,
                          answersByQuestionId,
                        );
                        final selected = selectedQuestionId == item.question.id;
                        return InkWell(
                          onTap: () => onSelectQuestion(item.question),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _circleColorForStatus(status),
                              shape: BoxShape.circle,
                              border: selected
                                  ? Border.all(
                                      color: const Color(0xFF2563EB),
                                      width: 2.2,
                                    )
                                  : null,
                              boxShadow: selected
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x262563EB),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              '${item.displayNumber}',
                              style: TextStyle(
                                color: status == _AnswerStatus.unanswered
                                    ? const Color(0xFF344054)
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _LegendDot(color: Color(0xFF10B981), text: 'Câu đúng'),
                _LegendDot(color: Color(0xFFFF1F5B), text: 'Câu sai'),
                _LegendDot(color: Color(0xFFCBD5E1), text: 'Chưa trả lời'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizContentView extends StatelessWidget {
  const _QuizContentView({
    required this.question,
    required this.raw,
    required this.style,
    required this.maxImageHeight,
    this.option,
  });

  final QuizQuestion question;
  final String raw;
  final QuizOption? option;
  final TextStyle style;
  final double maxImageHeight;

  @override
  Widget build(BuildContext context) {
    final chunks = _tokenizeContent(raw, question, option: option);
    if (chunks.isEmpty) {
      final text = _renderText(raw);
      if (text.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(text, style: style);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: chunks.map((chunk) {
        switch (chunk.type) {
          case _ContentChunkType.imageBytes:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImageHeight),
                child: Image.memory(chunk.bytes!, fit: BoxFit.contain),
              ),
            );
          case _ContentChunkType.imageUrl:
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImageHeight),
                child: Image.network(
                  chunk.value,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Text(
                    '[Không tải được hình ảnh/công thức]',
                    style: style.copyWith(
                      color: QuizDetailPalette.textMuted,
                      fontSize: (style.fontSize ?? 14) - 1,
                    ),
                  ),
                ),
              ),
            );
          case _ContentChunkType.mathText:
            final mathText = _renderText(chunk.value);
            if (mathText.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                mathText,
                style: style.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          case _ContentChunkType.text:
            final text = _renderText(chunk.value);
            if (text.isEmpty) {
              return const SizedBox.shrink();
            }
            return Text(text, style: style);
        }
      }).toList(),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
  });

  final int correct;
  final int incorrect;
  final int unanswered;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: CustomPaint(
        painter: _DonutPainter(
          correct: correct,
          incorrect: incorrect,
          unanswered: unanswered,
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
  });

  final int correct;
  final int incorrect;
  final int unanswered;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 24;
    const strokeWidth = 44.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
      rect,
      -1.5707963267948966,
      6.283185307179586,
      false,
      basePaint,
    );

    final total = correct + incorrect + unanswered;
    if (total <= 0) {
      return;
    }

    double start = -1.5707963267948966;
    final segments = [
      (correct, const Color(0xFF22C55E)),
      (incorrect, const Color(0xFFFF1F5B)),
      (unanswered, const Color(0xFF98A2B3)),
    ];

    for (final segment in segments) {
      final value = segment.$1;
      if (value <= 0) {
        continue;
      }
      final sweep = (value / total) * 6.283185307179586;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final holePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - strokeWidth / 2.2, holePaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.correct != correct ||
        oldDelegate.incorrect != incorrect ||
        oldDelegate.unanswered != unanswered;
  }
}

class _ResultSectionCard extends StatelessWidget {
  const _ResultSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(padding: const EdgeInsets.all(22), child: child),
    );
  }
}

class _ScoreAreaPanel extends StatelessWidget {
  const _ScoreAreaPanel({
    required this.label,
    required this.totalScore,
    required this.firstModuleScore,
    required this.secondModuleScore,
    required this.progress,
    required this.color,
  });

  final String label;
  final int totalScore;
  final int? firstModuleScore;
  final int? secondModuleScore;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF344054),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 52),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$totalScore',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 64),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Module 1:',
                      style: TextStyle(color: Color(0xFF475467)),
                    ),
                  ),
                  Text(
                    firstModuleScore?.toString() ?? '-',
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Module 2:',
                      style: TextStyle(color: Color(0xFF475467)),
                    ),
                  ),
                  Text(
                    secondModuleScore?.toString() ?? '-',
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.value,
    this.suffix = '',
    this.progress,
    required this.progressColor,
  });

  final String label;
  final String value;
  final String suffix;
  final double? progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 14),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: QuizDetailPalette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              children: [
                TextSpan(text: value),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress?.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownPanel extends StatelessWidget {
  const _BreakdownPanel({required this.title, required this.items});

  final String title;
  final List<_BreakdownBucket> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text(
              'Chưa có dữ liệu.',
              style: TextStyle(color: Color(0xFF667085)),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE4E7EC)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: List<Widget>.generate(items.length, (index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: index == items.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Color(0xFFE4E7EC)),
                            ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: QuizDetailPalette.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${item.count} questions',
                          style: const TextStyle(
                            color: Color(0xFF475467),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475467),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OptionFlag extends StatelessWidget {
  const _OptionFlag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ResultCountRow extends StatelessWidget {
  const _ResultCountRow({
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final String label;
  final int value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexedQuestion {
  const _IndexedQuestion({required this.displayNumber, required this.question});

  final int displayNumber;
  final QuizQuestion question;
}

class _BreakdownBucket {
  const _BreakdownBucket({required this.name, required this.count});

  final String name;
  final int count;
}

class _AiInsight {
  const _AiInsight({required this.title, required this.body});

  final String title;
  final String body;
}

class _BadgePresentation {
  const _BadgePresentation({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

class _StatusMessagePresentation {
  const _StatusMessagePresentation({
    required this.text,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color border;
  final Color foreground;
}

class _OptionPresentation {
  const _OptionPresentation({
    required this.background,
    required this.border,
    required this.labelColor,
    required this.contentColor,
  });

  final Color background;
  final Color border;
  final Color labelColor;
  final Color contentColor;
}

enum _AnswerStatus { correct, incorrect, unanswered }

const List<String> _satModuleOrder = [
  'Module I: Reading and Writing',
  'Module II: Reading and Writing',
  'Module I: Math',
  'Module II: Math',
];

_AnswerStatus _statusOf(
  QuizQuestion question,
  Map<String, Map<String, dynamic>> answersByQuestionId,
) {
  final answer = answersByQuestionId[question.id];
  if (answer == null) {
    return _AnswerStatus.unanswered;
  }

  final selected = _asText(answer['selected_option']);
  final text = _asText(answer['answer_text']);
  final raw = _asText(answer['user_answer']);
  final hasAnswer = selected.isNotEmpty || text.isNotEmpty || raw.isNotEmpty;
  if (!hasAnswer) {
    return _AnswerStatus.unanswered;
  }

  return answer['is_correct'] == true
      ? _AnswerStatus.correct
      : _AnswerStatus.incorrect;
}

IconData _iconForStatus(_AnswerStatus status) {
  switch (status) {
    case _AnswerStatus.correct:
      return Icons.check_circle_rounded;
    case _AnswerStatus.incorrect:
      return Icons.cancel_rounded;
    case _AnswerStatus.unanswered:
      return Icons.remove_circle_rounded;
  }
}

Color _circleColorForStatus(_AnswerStatus status) {
  switch (status) {
    case _AnswerStatus.correct:
      return const Color(0xFF10B981);
    case _AnswerStatus.incorrect:
      return const Color(0xFFFF1F5B);
    case _AnswerStatus.unanswered:
      return const Color(0xFFCBD5E1);
  }
}

_BadgePresentation _badgeForStatus(_AnswerStatus status) {
  switch (status) {
    case _AnswerStatus.correct:
      return const _BadgePresentation(
        label: 'Đúng',
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF15803D),
      );
    case _AnswerStatus.incorrect:
      return const _BadgePresentation(
        label: 'Sai',
        background: Color(0xFFFFE4E8),
        foreground: Color(0xFFBE123C),
      );
    case _AnswerStatus.unanswered:
      return const _BadgePresentation(
        label: 'Chưa làm',
        background: Color(0xFFF2F4F7),
        foreground: Color(0xFF667085),
      );
  }
}

_StatusMessagePresentation _statusMessageFor(_AnswerStatus status) {
  switch (status) {
    case _AnswerStatus.correct:
      return const _StatusMessagePresentation(
        text: 'Bạn đã trả lời đúng câu hỏi này.',
        background: Color(0xFFECFDF3),
        border: Color(0xFF86EFAC),
        foreground: Color(0xFF15803D),
      );
    case _AnswerStatus.incorrect:
      return const _StatusMessagePresentation(
        text: 'Bạn đã trả lời sai câu hỏi này.',
        background: Color(0xFFFFF1F3),
        border: Color(0xFFFDA4AF),
        foreground: Color(0xFFBE123C),
      );
    case _AnswerStatus.unanswered:
      return const _StatusMessagePresentation(
        text: 'Bạn chưa trả lời câu hỏi này.',
        background: Color(0xFFF8FAFC),
        border: Color(0xFFCBD5E1),
        foreground: Color(0xFF475467),
      );
  }
}

_OptionPresentation _optionState(
  QuizQuestion question,
  QuizOption option,
  Map<String, dynamic>? answer,
) {
  final selected = _isUserSelectedOption(answer, option);
  if (option.isCorrect) {
    return const _OptionPresentation(
      background: Color(0xFFDCFCE7),
      border: Color(0xFF10B981),
      labelColor: Color(0xFF059669),
      contentColor: Color(0xFF065F46),
    );
  }
  if (selected) {
    return const _OptionPresentation(
      background: Color(0xFFFFD7DF),
      border: Color(0xFFFF4D6D),
      labelColor: Color(0xFFE11D48),
      contentColor: Color(0xFF9F1239),
    );
  }
  return const _OptionPresentation(
    background: Colors.white,
    border: Color(0xFFD0D5DD),
    labelColor: Color(0xFF344054),
    contentColor: Color(0xFF344054),
  );
}

bool _isUserSelectedOption(Map<String, dynamic>? answer, QuizOption option) {
  if (answer == null) {
    return false;
  }
  return _asText(answer['selected_option']) == option.id;
}

bool _isEssayQuestion(QuizQuestion question) {
  final type = question.type.toLowerCase();
  return question.options.isEmpty ||
      type == 'essay' ||
      type == 'short-answer' ||
      type == 'numeric';
}

bool _hasTranscript(QuizQuestion question) {
  return _stripHtml(question.transcript).isNotEmpty;
}

String _userAnswerOf(QuizQuestion question, Map<String, dynamic>? answer) {
  if (answer == null) {
    return '-';
  }

  final text = _asText(answer['answer_text']);
  if (text.isNotEmpty) {
    return text;
  }

  final selected = _asText(answer['selected_option']);
  if (selected.isNotEmpty) {
    final optionIndex = question.options.indexWhere(
      (item) => item.id == selected,
    );
    if (optionIndex >= 0) {
      return '${_optionLabel(optionIndex)}. ${_stripHtml(question.options[optionIndex].content)}'
          .trim();
    }
  }

  final raw = _asText(answer['user_answer']);
  return raw.isEmpty ? '-' : raw;
}

String _optionLabel(int index) => String.fromCharCode(65 + index);

String? _moduleKeyOf(String moduleName) {
  switch (moduleName) {
    case 'Module I: Reading and Writing':
      return 'rw1';
    case 'Module II: Reading and Writing':
      return 'rw2';
    case 'Module I: Math':
      return 'm1';
    case 'Module II: Math':
      return 'm2';
  }
  return null;
}

String _formatClock(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final minutes = clamped ~/ 60;
  final secs = (clamped % 60).toString().padLeft(2, '0');
  return '$minutes:$secs';
}

String _formatReadableDuration(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;

  final parts = <String>[];
  if (hours > 0) {
    parts.add('$hours giờ');
  }
  if (minutes > 0) {
    parts.add('$minutes phút');
  }
  if (secs > 0 || parts.isEmpty) {
    parts.add('$secs giây');
  }
  return parts.join(' ');
}

String? _normalizeDomainLabel(String value) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}

String? _resolveQuestionArea(QuizQuestion question) {
  final hints = [
    question.effectiveModuleName,
    question.moduleName,
    question.module,
  ].join(' ').toLowerCase();

  if (hints.contains('reading') ||
      hints.contains('writing') ||
      hints.contains('rw')) {
    return 'rw';
  }
  if (hints.contains('math')) {
    return 'math';
  }
  return null;
}

Color _progressColor(double percent) {
  if (percent >= 75) {
    return const Color(0xFF16A34A);
  }
  if (percent >= 50) {
    return const Color(0xFF2563EB);
  }
  if (percent >= 25) {
    return const Color(0xFFD97706);
  }
  return const Color(0xFFDC2626);
}

String _stripHtml(String value) {
  return value
      .replaceAll(RegExp(r'<math[\s\S]*?</math>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _asText(dynamic value) => (value ?? '').toString().trim();

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
    }
  }

  final compactChunks = _compactTextChunks(chunks);
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
      return node.children
          .whereType<xml.XmlElement>()
          .where((el) => el.name.local.toLowerCase() == 'mtr')
          .map(_renderMathXmlNode)
          .where((row) => row.trim().isNotEmpty)
          .join(' ; ');
    case 'mtr':
      return node.children
          .whereType<xml.XmlElement>()
          .where((el) => el.name.local.toLowerCase() == 'mtd')
          .map(_renderMathXmlNode)
          .join(' | ');
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

enum _ContentChunkType { text, mathText, imageUrl, imageBytes }

class _ContentChunk {
  const _ContentChunk._({required this.type, this.value = '', this.bytes});

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
    return _ContentChunk._(type: _ContentChunkType.imageBytes, bytes: bytes);
  }
}
