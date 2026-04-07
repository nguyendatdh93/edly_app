import 'dart:async';
import 'dart:math' as math;

import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

part 'exam_history/question.dart';
part 'exam_history/question_action_tabs.dart';
part 'exam_history/type/comprehension.dart';
part 'exam_history/type/drag_drop.dart';
part 'exam_history/type/essay.dart';
part 'exam_history/type/essay_yes_no.dart';
part 'exam_history/type/long_answer.dart';
part 'exam_history/type/multiple_choices.dart';
part 'exam_history/type/single_choice.dart';
part 'exam_history/type/yes_no.dart';
part 'exam_history/tab/comment_item.dart';
part 'exam_history/tab/discussion.dart';
part 'exam_history/tab/note.dart';
part 'exam_history/tab/solution.dart';

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
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _questionKeys = {};
  final Map<String, bool> _transcriptOpen = {};

  String? _selectedQuestionId;
  String? _activeModuleName;
  bool _showScrollToTop = false;

  List<QuizQuestion> get _questions {
    final rows = [...widget.result.questions];
    rows.sort((a, b) {
      if (a.sort == 0 && b.sort == 0) {
        return 0;
      }
      if (a.sort == 0) {
        return 1;
      }
      if (b.sort == 0) {
        return -1;
      }
      return a.sort.compareTo(b.sort);
    });
    return rows;
  }

  String get _displayQuizName {
    if (widget.result.quizName.trim().isNotEmpty) {
      return widget.result.quizName.trim();
    }
    return widget.quizName.trim();
  }

  int get _finalScore => widget.result.score.inferredTotalScore;

  int get _usedSeconds {
    final value = widget.result.secondLeft;
    if (value < 0) {
      return 0;
    }
    return value;
  }

  bool get _hasAiQuestions {
    return _questions.any((item) => _isAiType(item.type));
  }

  Map<String, Map<String, dynamic>> get _answersByQuestionId {
    final result = <String, Map<String, dynamic>>{};
    for (final answer in widget.result.answers) {
      final questionId = _asText(answer['question_id']);
      if (questionId.isEmpty) {
        continue;
      }
      result[questionId] = answer;
    }
    return result;
  }

  List<_IndexedQuestion> get _indexedQuestions {
    return List<_IndexedQuestion>.generate(_questions.length, (index) {
      return _IndexedQuestion(
        displayNumber: index + 1,
        question: _questions[index],
      );
    });
  }

  Map<String, List<_IndexedQuestion>> get _groupedQuestions {
    final grouped = <String, List<_IndexedQuestion>>{};
    for (final item in _indexedQuestions) {
      final moduleName = _moduleNameOf(item.question);
      grouped.putIfAbsent(moduleName, () => <_IndexedQuestion>[]).add(item);
    }
    return grouped;
  }

  _ResultStats get _stats {
    final answers = _answersByQuestionId;
    final total = _indexedQuestions.length;
    var correct = 0;
    var incorrect = 0;
    var pending = 0;
    var unanswered = 0;

    for (final item in _indexedQuestions) {
      final status = _statusOf(item.question, answers);
      switch (status) {
        case _AnswerStatus.correct:
          correct++;
          break;
        case _AnswerStatus.incorrect:
          incorrect++;
          break;
        case _AnswerStatus.pending:
          pending++;
          break;
        case _AnswerStatus.unanswered:
          unanswered++;
          break;
      }
    }

    final answered = total - unanswered;
    final gradedAnswered = correct + incorrect;
    final completion = total == 0 ? 0 : ((answered / total) * 100).round();
    final accuracy = gradedAnswered == 0
        ? 0
        : ((correct / gradedAnswered) * 100).round();

    return _ResultStats(
      total: total,
      correct: correct,
      incorrect: incorrect,
      pending: pending,
      unanswered: unanswered,
      answered: answered,
      completion: completion,
      accuracy: accuracy,
    );
  }

  List<_ModuleSummary> get _moduleSummaries {
    final answers = _answersByQuestionId;
    final rows = <_ModuleSummary>[];

    for (final entry in _groupedQuestions.entries) {
      var correct = 0;
      var incorrect = 0;
      var pending = 0;
      var unanswered = 0;

      for (final item in entry.value) {
        final status = _statusOf(item.question, answers);
        switch (status) {
          case _AnswerStatus.correct:
            correct++;
            break;
          case _AnswerStatus.incorrect:
            incorrect++;
            break;
          case _AnswerStatus.pending:
            pending++;
            break;
          case _AnswerStatus.unanswered:
            unanswered++;
            break;
        }
      }

      final total = entry.value.length;
      final gradedAnswered = correct + incorrect;
      final accuracy = gradedAnswered == 0
          ? 0
          : ((correct / gradedAnswered) * 100).round();

      rows.add(
        _ModuleSummary(
          name: entry.key,
          total: total,
          correct: correct,
          incorrect: incorrect,
          pending: pending,
          unanswered: unanswered,
          accuracy: accuracy,
        ),
      );
    }

    return rows;
  }

  List<_TypeSummary> get _typeSummaries {
    final answers = _answersByQuestionId;
    final map = <String, _MutableTypeSummary>{
      'single-choice': _MutableTypeSummary(
        key: 'single-choice',
        label: 'Trắc nghiệm 4 lựa chọn',
      ),
      'yes-no': _MutableTypeSummary(
        key: 'yes-no',
        label: 'Trắc nghiệm Đúng / Sai',
      ),
      'essay': _MutableTypeSummary(
        key: 'essay',
        label: 'Tự luận / Trả lời ngắn',
      ),
    };

    for (final item in _indexedQuestions) {
      final bucket = _typeBucket(item.question.type);
      final target = map[bucket];
      if (target == null) {
        continue;
      }

      final status = _statusOf(item.question, answers);
      target.total++;
      if (status != _AnswerStatus.unanswered) {
        target.answered++;
      }
      if (status == _AnswerStatus.correct) {
        target.correct++;
      }
    }

    return map.values.map((item) => item.toSummary()).toList();
  }

  @override
  void initState() {
    super.initState();

    if (_indexedQuestions.isNotEmpty) {
      _selectedQuestionId = _indexedQuestions.first.question.id;
      _activeModuleName = _moduleNameOf(_indexedQuestions.first.question);
    }

    _scrollController.addListener(_handleScrollChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollChanged() {
    final shouldShow =
        _scrollController.hasClients && _scrollController.offset > 520;
    if (shouldShow == _showScrollToTop) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showScrollToTop = shouldShow;
    });
  }

  void _selectQuestion(_IndexedQuestion indexedQuestion, {bool scroll = true}) {
    final question = indexedQuestion.question;
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedQuestionId = question.id;
      _activeModuleName = _moduleNameOf(question);
    });

    if (!scroll) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToQuestion(question.id);
    });
  }

  Future<void> _scrollToQuestion(String questionId) async {
    final context = _questionKeys[questionId]?.currentContext;
    if (context == null) {
      return;
    }

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.06,
    );
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }

    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _toggleTranscript(String questionId) {
    setState(() {
      _transcriptOpen[questionId] = !(_transcriptOpen[questionId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final isWide = viewport.width >= 1080;
    final createdAt = widget.result.createdAt;
    final submittedAt = createdAt == null
        ? ''
        : DateFormat('HH:mm • dd/MM/yyyy').format(createdAt);

    final stats = _stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: _ResultHero(
                quizName: _displayQuizName,
                submittedAt: submittedAt,
                usedTimeText: _formatReadableDuration(_usedSeconds),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 16 : 12,
                      16,
                      isWide ? 16 : 12,
                      24,
                    ),
                    child: Column(
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _OverviewCard(
                                  stats: stats,
                                  hasAiInsight: _hasAiQuestions,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _StatisticsCard(
                                  finalScore: _finalScore,
                                  usedSeconds: _usedSeconds,
                                  moduleSummaries: _moduleSummaries,
                                  typeSummaries: _typeSummaries,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _OverviewCard(
                                stats: stats,
                                hasAiInsight: _hasAiQuestions,
                              ),
                              const SizedBox(height: 12),
                              _StatisticsCard(
                                finalScore: _finalScore,
                                usedSeconds: _usedSeconds,
                                moduleSummaries: _moduleSummaries,
                                typeSummaries: _typeSummaries,
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        _ReviewSection(
                          isWide: isWide,
                          groupedQuestions: _groupedQuestions,
                          indexedQuestions: _indexedQuestions,
                          selectedQuestionId: _selectedQuestionId,
                          activeModuleName: _activeModuleName,
                          answersByQuestionId: _answersByQuestionId,
                          questionKeys: _questionKeys,
                          transcriptOpen: _transcriptOpen,
                          onSelectQuestion: _selectQuestion,
                          onToggleTranscript: _toggleTranscript,
                          onQuickNavigate: (indexedQuestion) {
                            _selectQuestion(indexedQuestion, scroll: true);
                          },
                        ),
                      ],
                    ),
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

class _ResultHero extends StatelessWidget {
  const _ResultHero({
    required this.quizName,
    required this.submittedAt,
    required this.usedTimeText,
  });

  final String quizName;
  final String submittedAt;
  final String usedTimeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Kết quả bài thi',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Quay lại'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  quizName,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    if (submittedAt.isNotEmpty)
                      _HeroMeta(
                        icon: Icons.verified_rounded,
                        text: 'Nộp lúc $submittedAt',
                      ),
                    _HeroMeta(
                      icon: Icons.schedule_rounded,
                      text: 'Thời gian làm bài: $usedTimeText',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFBFDBFE), size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.stats, required this.hasAiInsight});

  final _ResultStats stats;
  final bool hasAiInsight;

  @override
  Widget build(BuildContext context) {
    final accuracyColor = _accuracyColor(stats.accuracy);

    return _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Tổng quan kết quả',
                style: TextStyle(
                  color: QuizDetailPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: _DonutChart(
              correct: stats.correct,
              incorrect: stats.incorrect,
              unanswered: stats.unanswered,
              pending: stats.pending,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _LegendDot(
                color: const Color(0xFF10B981),
                text: '${stats.correct} Đúng',
              ),
              _LegendDot(
                color: const Color(0xFFEF4444),
                text: '${stats.incorrect} Sai',
              ),
              _LegendDot(
                color: const Color(0xFF94A3B8),
                text: '${stats.unanswered} Chưa làm',
              ),
              if (stats.pending > 0)
                _LegendDot(
                  color: const Color(0xFFF59E0B),
                  text: '${stats.pending} Chờ AI',
                ),
            ],
          ),
          const SizedBox(height: 18),
          _ProgressRow(
            label: 'Hoàn thành',
            valueText: '${stats.completion}%',
            subtitle: '${stats.answered} / ${stats.total} câu',
            value: (stats.completion / 100).clamp(0.0, 1.0),
            color: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Độ chính xác',
            valueText: '${stats.accuracy}%',
            subtitle:
                '${stats.correct} đúng / ${stats.correct + stats.incorrect} câu đã chấm',
            value: (stats.accuracy / 100).clamp(0.0, 1.0),
            color: accuracyColor,
          ),
          if (hasAiInsight) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI có thể tiếp tục đánh giá các câu tự luận.',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.finalScore,
    required this.usedSeconds,
    required this.moduleSummaries,
    required this.typeSummaries,
  });

  final int finalScore;
  final int usedSeconds;
  final List<_ModuleSummary> moduleSummaries;
  final List<_TypeSummary> typeSummaries;

  @override
  Widget build(BuildContext context) {
    final showModule = moduleSummaries.length > 1;

    return _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text(
                'Thống kê',
                style: TextStyle(
                  color: QuizDetailPalette.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              if (compact) {
                return Column(
                  children: [
                    _HighlightMetric(
                      title: 'Tổng điểm',
                      value: '$finalScore',
                      subtitle: 'Kết quả sau khi chấm tự động',
                      color: const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 10),
                    _HighlightMetric(
                      title: 'Thời gian làm bài',
                      value: _formatClock(usedSeconds),
                      subtitle: _formatReadableDuration(usedSeconds),
                      color: const Color(0xFFDB2777),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _HighlightMetric(
                      title: 'Tổng điểm',
                      value: '$finalScore',
                      subtitle: 'Kết quả sau khi chấm tự động',
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HighlightMetric(
                      title: 'Thời gian làm bài',
                      value: _formatClock(usedSeconds),
                      subtitle: _formatReadableDuration(usedSeconds),
                      color: const Color(0xFFDB2777),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            showModule
                ? 'Sơ đồ kết quả theo module'
                : 'Phân bố kết quả theo loại câu hỏi',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (showModule)
            Column(
              children: moduleSummaries
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ModuleSummaryRow(summary: item),
                    ),
                  )
                  .toList(),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: typeSummaries
                  .map((item) => _TypeSummaryCard(summary: item))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.isWide,
    required this.groupedQuestions,
    required this.indexedQuestions,
    required this.selectedQuestionId,
    required this.activeModuleName,
    required this.answersByQuestionId,
    required this.questionKeys,
    required this.transcriptOpen,
    required this.onSelectQuestion,
    required this.onToggleTranscript,
    required this.onQuickNavigate,
  });

  final bool isWide;
  final Map<String, List<_IndexedQuestion>> groupedQuestions;
  final List<_IndexedQuestion> indexedQuestions;
  final String? selectedQuestionId;
  final String? activeModuleName;
  final Map<String, Map<String, dynamic>> answersByQuestionId;
  final Map<String, GlobalKey> questionKeys;
  final Map<String, bool> transcriptOpen;
  final ValueChanged<_IndexedQuestion> onSelectQuestion;
  final ValueChanged<String> onToggleTranscript;
  final ValueChanged<_IndexedQuestion> onQuickNavigate;

  @override
  Widget build(BuildContext context) {
    if (indexedQuestions.isEmpty) {
      return _ResultSectionCard(
        child: Column(
          children: const [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 42,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 10),
            Text(
              'Chưa có dữ liệu câu hỏi để hiển thị lịch sử làm bài.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final questionList = _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết câu hỏi',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          ...indexedQuestions.map((indexedQuestion) {
            final question = indexedQuestion.question;
            final key = questionKeys.putIfAbsent(
              question.id,
              () => GlobalKey(),
            );
            final answer = answersByQuestionId[question.id];
            final isSelected = selectedQuestionId == question.id;

            return Padding(
              key: key,
              padding: const EdgeInsets.only(bottom: 14),
              child: _QuestionReviewCard(
                indexedQuestion: indexedQuestion,
                question: question,
                answer: answer,
                isSelected: isSelected,
                isTranscriptOpen: transcriptOpen[question.id] ?? false,
                onToggleTranscript: _hasTranscript(question)
                    ? () => onToggleTranscript(question.id)
                    : null,
                onTap: () => onSelectQuestion(indexedQuestion),
              ),
            );
          }),
        ],
      ),
    );

    final navigator = _ResultSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Danh sách câu hỏi',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          ...groupedQuestions.entries.map((entry) {
            final moduleName = entry.key;
            final rows = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          moduleName,
                          style: TextStyle(
                            color: activeModuleName == moduleName
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF475467),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${rows.length} câu',
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rows.map((item) {
                      final status = _statusOf(
                        item.question,
                        answersByQuestionId,
                      );
                      final selected = selectedQuestionId == item.question.id;
                      final colors = _quickButtonColors(status, selected);

                      return InkWell(
                        onTap: () => onQuickNavigate(item),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.border),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.displayNumber}',
                            style: TextStyle(
                              color: colors.foreground,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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
          const Divider(height: 18),
          const Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _LegendDot(color: Color(0xFF10B981), text: 'Câu đúng'),
              _LegendDot(color: Color(0xFFEF4444), text: 'Câu sai'),
              _LegendDot(color: Color(0xFFCBD5E1), text: 'Chưa trả lời'),
              _LegendDot(color: Color(0xFFF59E0B), text: 'Chờ AI chấm'),
            ],
          ),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: questionList),
          const SizedBox(width: 14),
          Expanded(child: navigator),
        ],
      );
    }

    return Column(
      children: [navigator, const SizedBox(height: 12), questionList],
    );
  }
}

class _ResultSectionCard extends StatelessWidget {
  const _ResultSectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.valueText,
    required this.subtitle,
    required this.value,
    required this.color,
  });

  final String label;
  final String valueText;
  final String subtitle;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF475467),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }
}

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFE2E8F0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSummaryCard extends StatelessWidget {
  const _TypeSummaryCard({required this.summary});

  final _TypeSummary summary;

  @override
  Widget build(BuildContext context) {
    final accent = switch (summary.key) {
      'single-choice' => const Color(0xFF2563EB),
      'yes-no' => const Color(0xFF9333EA),
      _ => const Color(0xFFEA580C),
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.label,
            style: const TextStyle(
              color: Color(0xFF475467),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${summary.answered}',
                style: TextStyle(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ ${summary.total}',
                style: const TextStyle(
                  color: Color(0xFF98A2B3),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.correct} câu đúng',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleSummaryRow extends StatelessWidget {
  const _ModuleSummaryRow({required this.summary});

  final _ModuleSummary summary;

  @override
  Widget build(BuildContext context) {
    final total = summary.total == 0 ? 1 : summary.total;
    final correctPart = summary.correct / total;
    final incorrectPart = summary.incorrect / total;
    final pendingPart = summary.pending / total;
    final unansweredPart = summary.unanswered / total;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.name,
                  style: const TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${summary.accuracy}%',
                style: TextStyle(
                  color: _accuracyColor(summary.accuracy),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (correctPart > 0)
                    Expanded(
                      flex: math.max(1, (correctPart * 1000).round()),
                      child: const ColoredBox(color: Color(0xFF10B981)),
                    ),
                  if (incorrectPart > 0)
                    Expanded(
                      flex: math.max(1, (incorrectPart * 1000).round()),
                      child: const ColoredBox(color: Color(0xFFEF4444)),
                    ),
                  if (pendingPart > 0)
                    Expanded(
                      flex: math.max(1, (pendingPart * 1000).round()),
                      child: const ColoredBox(color: Color(0xFFF59E0B)),
                    ),
                  if (unansweredPart > 0)
                    Expanded(
                      flex: math.max(1, (unansweredPart * 1000).round()),
                      child: const ColoredBox(color: Color(0xFFCBD5E1)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.correct} đúng · ${summary.incorrect} sai · ${summary.unanswered} chưa làm'
            '${summary.pending > 0 ? ' · ${summary.pending} chờ AI' : ''}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.correct,
    required this.incorrect,
    required this.unanswered,
    required this.pending,
  });

  final int correct;
  final int incorrect;
  final int unanswered;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _DonutPainter(
          correct: correct,
          incorrect: incorrect,
          unanswered: unanswered,
          pending: pending,
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
    required this.pending,
  });

  final int correct;
  final int incorrect;
  final int unanswered;
  final int pending;

  @override
  void paint(Canvas canvas, Size size) {
    final total = correct + incorrect + unanswered + pending;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const strokeWidth = 32.0;

    final trackPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);

    if (total <= 0) {
      return;
    }

    final segments = [
      (correct, const Color(0xFF10B981)),
      (incorrect, const Color(0xFFEF4444)),
      (pending, const Color(0xFFF59E0B)),
      (unanswered, const Color(0xFF94A3B8)),
    ];

    var start = -math.pi / 2;
    for (final segment in segments) {
      final value = segment.$1;
      if (value <= 0) {
        continue;
      }

      final sweep = (value / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - strokeWidth / 2, innerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: const TextStyle(
          color: QuizDetailPalette.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 - 6,
      ),
    );

    final captionPainter = TextPainter(
      text: const TextSpan(
        text: 'câu hỏi',
        style: TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    captionPainter.paint(
      canvas,
      Offset(center.dx - captionPainter.width / 2, center.dy + 16),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.correct != correct ||
        oldDelegate.incorrect != incorrect ||
        oldDelegate.unanswered != unanswered ||
        oldDelegate.pending != pending;
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF475467),
            fontSize: 12,
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
        Icon(icon, size: 16, color: color),
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

class _QuizContentView extends StatelessWidget {
  const _QuizContentView({
    required this.question,
    required this.raw,
    required this.style,
    required this.maxImageHeight,
    this.option,
  });

  final QuizQuestion question;
  final QuizOption? option;
  final String raw;
  final TextStyle style;
  final double maxImageHeight;

  @override
  Widget build(BuildContext context) {
    final renderedText = _renderTextWithMath(raw, question, option: option);
    final urls = _collectImageUrls(question, raw, option: option);

    if (renderedText.isEmpty && urls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (renderedText.isNotEmpty) Text(renderedText, style: style),
        if (urls.isNotEmpty) ...[
          if (renderedText.isNotEmpty) const SizedBox(height: 8),
          ...urls.map((url) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxImageHeight),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      '[Không tải được hình ảnh]',
                      style: style.copyWith(
                        color: QuizDetailPalette.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class _ResultStats {
  const _ResultStats({
    required this.total,
    required this.correct,
    required this.incorrect,
    required this.pending,
    required this.unanswered,
    required this.answered,
    required this.completion,
    required this.accuracy,
  });

  final int total;
  final int correct;
  final int incorrect;
  final int pending;
  final int unanswered;
  final int answered;
  final int completion;
  final int accuracy;
}

class _ModuleSummary {
  const _ModuleSummary({
    required this.name,
    required this.total,
    required this.correct,
    required this.incorrect,
    required this.pending,
    required this.unanswered,
    required this.accuracy,
  });

  final String name;
  final int total;
  final int correct;
  final int incorrect;
  final int pending;
  final int unanswered;
  final int accuracy;
}

class _TypeSummary {
  const _TypeSummary({
    required this.key,
    required this.label,
    required this.total,
    required this.answered,
    required this.correct,
  });

  final String key;
  final String label;
  final int total;
  final int answered;
  final int correct;
}

class _MutableTypeSummary {
  _MutableTypeSummary({required this.key, required this.label});

  final String key;
  final String label;
  int total = 0;
  int answered = 0;
  int correct = 0;

  _TypeSummary toSummary() {
    return _TypeSummary(
      key: key,
      label: label,
      total: total,
      answered: answered,
      correct: correct,
    );
  }
}

class _IndexedQuestion {
  const _IndexedQuestion({required this.displayNumber, required this.question});

  final int displayNumber;
  final QuizQuestion question;
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

class _QuickButtonPresentation {
  const _QuickButtonPresentation({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

enum _AnswerStatus { correct, incorrect, unanswered, pending }

String _moduleNameOf(QuizQuestion question) {
  final name = question.effectiveModuleName.trim();
  return name.isEmpty ? 'Quiz' : name;
}

String _typeBucket(String type) {
  final normalized = type.toLowerCase().trim();
  switch (normalized) {
    case 'yes-no':
      return 'yes-no';
    case 'essay':
    case 'essay-yes-no':
    case 'long-answer':
    case 'short-answer':
    case 'numeric':
      return 'essay';
    default:
      return 'single-choice';
  }
}

bool _isAiType(String type) {
  final normalized = type.toLowerCase().trim();
  return normalized == 'long-answer' || normalized == 'essay';
}

_AnswerStatus _statusOf(
  QuizQuestion question,
  Map<String, Map<String, dynamic>> answersByQuestionId,
) {
  final answer = answersByQuestionId[question.id];
  if (!_hasAnyAnswer(answer)) {
    return _AnswerStatus.unanswered;
  }

  final correctness = answer?['is_correct'];
  if (correctness == true) {
    return _AnswerStatus.correct;
  }
  if (correctness == false) {
    return _AnswerStatus.incorrect;
  }

  return _AnswerStatus.pending;
}

IconData _iconForStatus(_AnswerStatus status) {
  switch (status) {
    case _AnswerStatus.correct:
      return Icons.check_circle_rounded;
    case _AnswerStatus.incorrect:
      return Icons.cancel_rounded;
    case _AnswerStatus.pending:
      return Icons.hourglass_top_rounded;
    case _AnswerStatus.unanswered:
      return Icons.remove_circle_outline_rounded;
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
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFFB91C1C),
      );
    case _AnswerStatus.pending:
      return const _BadgePresentation(
        label: 'Chờ AI chấm',
        background: Color(0xFFFFF7ED),
        foreground: Color(0xFFB45309),
      );
    case _AnswerStatus.unanswered:
      return const _BadgePresentation(
        label: 'Chưa làm',
        background: Color(0xFFF1F5F9),
        foreground: Color(0xFF475467),
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
        background: Color(0xFFFEF2F2),
        border: Color(0xFFFCA5A5),
        foreground: Color(0xFFB91C1C),
      );
    case _AnswerStatus.pending:
      return const _StatusMessagePresentation(
        text: 'Câu này đang chờ hệ thống AI chấm điểm.',
        background: Color(0xFFFFF7ED),
        border: Color(0xFFFCD34D),
        foreground: Color(0xFFB45309),
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
  final type = question.type.toLowerCase().trim();

  if (type == 'yes-no') {
    final userAnswer = _resolveYesNoUserValue(answer, option.id);
    if (userAnswer == null) {
      if (option.isCorrect) {
        return const _OptionPresentation(
          background: Color(0xFFECFDF3),
          border: Color(0xFF86EFAC),
          labelColor: Color(0xFF15803D),
          contentColor: Color(0xFF166534),
        );
      }

      return const _OptionPresentation(
        background: Colors.white,
        border: Color(0xFFD0D5DD),
        labelColor: Color(0xFF344054),
        contentColor: Color(0xFF344054),
      );
    }

    if (userAnswer == option.isCorrect) {
      return const _OptionPresentation(
        background: Color(0xFFDCFCE7),
        border: Color(0xFF10B981),
        labelColor: Color(0xFF059669),
        contentColor: Color(0xFF065F46),
      );
    }

    return const _OptionPresentation(
      background: Color(0xFFFEE2E2),
      border: Color(0xFFEF4444),
      labelColor: Color(0xFFB91C1C),
      contentColor: Color(0xFF7F1D1D),
    );
  }

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
      background: Color(0xFFFEE2E2),
      border: Color(0xFFEF4444),
      labelColor: Color(0xFFB91C1C),
      contentColor: Color(0xFF7F1D1D),
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
  if (answer == null || option.id.trim().isEmpty) {
    return false;
  }

  final optionId = option.id.trim();

  final selected = _asText(answer['selected_option']).isNotEmpty
      ? _asText(answer['selected_option'])
      : _asText(answer['option_id']);

  if (selected.isNotEmpty && selected == optionId) {
    return true;
  }

  final userAnswer = answer['user_answer'];

  if (userAnswer is List) {
    return userAnswer.map(_asText).contains(optionId);
  }

  if (userAnswer is Map) {
    if (userAnswer.containsKey(optionId)) {
      return true;
    }
    if (userAnswer.containsKey(option.id)) {
      return true;
    }
  }

  final optionIds = answer['option_ids'];
  if (optionIds is List) {
    for (final item in optionIds) {
      if (item is! Map) {
        continue;
      }
      final currentId = _asText(item['option_id']);
      final value = item['value'];
      if (currentId == optionId && value == true) {
        return true;
      }
    }
  }

  final dragAnswers = answer['drag_answers'];
  if (dragAnswers is List) {
    return dragAnswers.map(_asText).contains(optionId);
  }

  return false;
}

bool? _resolveYesNoUserValue(Map<String, dynamic>? answer, String optionId) {
  if (answer == null || optionId.trim().isEmpty) {
    return null;
  }

  final userAnswer = answer['user_answer'];
  if (userAnswer is Map) {
    if (userAnswer.containsKey(optionId)) {
      final value = userAnswer[optionId];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final lowered = value.toLowerCase().trim();
        if (lowered == 'true' || lowered == '1') {
          return true;
        }
        if (lowered == 'false' || lowered == '0') {
          return false;
        }
      }
    }
  }

  final optionIds = answer['option_ids'];
  if (optionIds is List) {
    for (final item in optionIds) {
      if (item is! Map) {
        continue;
      }
      if (_asText(item['option_id']) != optionId) {
        continue;
      }
      final value = item['value'];
      if (value is bool) {
        return value;
      }
      if (value is String) {
        final lowered = value.toLowerCase().trim();
        if (lowered == 'true' || lowered == '1') {
          return true;
        }
        if (lowered == 'false' || lowered == '0') {
          return false;
        }
      }
    }
  }

  return null;
}

bool _hasTranscript(QuizQuestion question) {
  return _stripHtml(question.transcript).isNotEmpty;
}

String _userAnswerOf(QuizQuestion question, Map<String, dynamic>? answer) {
  if (answer == null) {
    return '-';
  }

  final textAnswer = _asText(answer['answer_text']).isNotEmpty
      ? _asText(answer['answer_text'])
      : _asText(answer['content']);

  if (textAnswer.isNotEmpty) {
    return textAnswer;
  }

  final selected = _asText(answer['selected_option']).isNotEmpty
      ? _asText(answer['selected_option'])
      : _asText(answer['option_id']);

  if (selected.isNotEmpty) {
    final optionIndex = question.options.indexWhere(
      (item) => item.id.trim() == selected,
    );
    if (optionIndex >= 0) {
      return '${_optionLabel(optionIndex)}. ${_stripHtml(question.options[optionIndex].content)}'
          .trim();
    }
    return selected;
  }

  final userAnswer = answer['user_answer'];
  if (userAnswer is List) {
    if (userAnswer.isEmpty) {
      return '-';
    }

    final labels = userAnswer.map(_asText).where((item) => item.isNotEmpty).map(
      (id) {
        final index = question.options.indexWhere((opt) => opt.id.trim() == id);
        if (index >= 0) {
          return _optionLabel(index);
        }
        return id;
      },
    ).toList();

    return labels.isEmpty ? '-' : labels.join(', ');
  }

  if (userAnswer is Map) {
    if (userAnswer.isEmpty) {
      return '-';
    }

    final normalized = <String>[];
    for (final option in question.options) {
      if (!userAnswer.containsKey(option.id)) {
        continue;
      }
      final value = userAnswer[option.id];
      if (value is bool) {
        normalized.add(
          '${_stripHtml(option.content)}: ${value ? 'Đúng' : 'Sai'}',
        );
      } else {
        normalized.add('${_stripHtml(option.content)}: ${_asText(value)}');
      }
    }

    if (normalized.isNotEmpty) {
      return normalized.join('\n');
    }

    return userAnswer.entries
        .map((entry) => '${entry.key}: ${_asText(entry.value)}')
        .join('\n');
  }

  final raw = _asText(userAnswer);
  return raw.isEmpty ? '-' : raw;
}

String _optionLabel(int index) => String.fromCharCode(65 + index);

bool _hasAnyAnswer(Map<String, dynamic>? answer) {
  if (answer == null) {
    return false;
  }

  if (_asText(answer['selected_option']).isNotEmpty ||
      _asText(answer['option_id']).isNotEmpty ||
      _asText(answer['answer_text']).isNotEmpty ||
      _asText(answer['content']).isNotEmpty) {
    return true;
  }

  final userAnswer = answer['user_answer'];
  if (userAnswer is String) {
    return userAnswer.trim().isNotEmpty;
  }
  if (userAnswer is List) {
    return userAnswer.isNotEmpty;
  }
  if (userAnswer is Map) {
    return userAnswer.isNotEmpty;
  }
  if (userAnswer != null && _asText(userAnswer).isNotEmpty) {
    return true;
  }

  final optionIds = answer['option_ids'];
  if (optionIds is List && optionIds.isNotEmpty) {
    return true;
  }

  final dragAnswers = answer['drag_answers'];
  if (dragAnswers is List && dragAnswers.isNotEmpty) {
    return true;
  }

  return false;
}

Color _accuracyColor(int accuracy) {
  if (accuracy >= 80) {
    return const Color(0xFF16A34A);
  }
  if (accuracy >= 60) {
    return const Color(0xFFD97706);
  }
  return const Color(0xFFDC2626);
}

_QuickButtonPresentation _quickButtonColors(
  _AnswerStatus status,
  bool selected,
) {
  if (selected) {
    return const _QuickButtonPresentation(
      background: Color(0xFF2563EB),
      border: Color(0xFF1D4ED8),
      foreground: Colors.white,
    );
  }

  switch (status) {
    case _AnswerStatus.correct:
      return const _QuickButtonPresentation(
        background: Color(0xFF10B981),
        border: Color(0xFF059669),
        foreground: Colors.white,
      );
    case _AnswerStatus.incorrect:
      return const _QuickButtonPresentation(
        background: Color(0xFFEF4444),
        border: Color(0xFFDC2626),
        foreground: Colors.white,
      );
    case _AnswerStatus.pending:
      return const _QuickButtonPresentation(
        background: Color(0xFFF59E0B),
        border: Color(0xFFD97706),
        foreground: Colors.white,
      );
    case _AnswerStatus.unanswered:
      return const _QuickButtonPresentation(
        background: Color(0xFFE2E8F0),
        border: Color(0xFFCBD5E1),
        foreground: Color(0xFF475467),
      );
  }
}

String _formatClock(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final hour = clamped ~/ 3600;
  final minute = (clamped % 3600) ~/ 60;
  final second = clamped % 60;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (hour > 0) {
    return '${twoDigits(hour)}:${twoDigits(minute)}:${twoDigits(second)}';
  }

  return '${twoDigits(minute)}:${twoDigits(second)}';
}

String _formatReadableDuration(int seconds) {
  final clamped = seconds < 0 ? 0 : seconds;
  final hour = clamped ~/ 3600;
  final minute = (clamped % 3600) ~/ 60;
  final second = clamped % 60;

  final parts = <String>[];
  if (hour > 0) {
    parts.add('$hour giờ');
  }
  if (minute > 0) {
    parts.add('$minute phút');
  }
  if (second > 0 || parts.isEmpty) {
    parts.add('$second giây');
  }
  return parts.join(' ');
}

String _renderTextWithMath(
  String raw,
  QuizQuestion question, {
  QuizOption? option,
}) {
  if (raw.trim().isEmpty) {
    return '';
  }

  final maths = <QuizMathAsset>[...question.maths, ...?option?.maths];
  var resolved = raw;

  for (final mathAsset in maths) {
    final placeholder = '[Math:${mathAsset.id}]';
    final mathText = _renderMathAsText(mathAsset);
    resolved = resolved.replaceAll(placeholder, mathText);
  }

  var text = _stripHtml(resolved);

  if (text.isEmpty && maths.isNotEmpty) {
    final mathText = maths
        .map(_renderMathAsText)
        .where((item) => item.isNotEmpty)
        .join(' ');
    text = mathText;
  }

  return text;
}

String _renderMathAsText(QuizMathAsset asset) {
  final mathml = asset.mathml.trim();
  if (mathml.isNotEmpty) {
    final stripped = _stripHtml(mathml);
    if (stripped.isNotEmpty) {
      return stripped;
    }
  }

  final omml = asset.omml.trim();
  if (omml.isNotEmpty) {
    final stripped = _stripHtml(omml);
    if (stripped.isNotEmpty) {
      return stripped;
    }
  }

  return '[Công thức]';
}

List<String> _collectImageUrls(
  QuizQuestion question,
  String raw, {
  QuizOption? option,
}) {
  final urls = <String>{};

  final srcRegex = RegExp(r'''src=("|')(.*?)\1''', caseSensitive: false);
  for (final match in srcRegex.allMatches(raw)) {
    final value = _asText(match.group(2));
    if (value.isNotEmpty) {
      urls.add(_normalizeAssetUrl(value));
    }
  }

  final imagePlaceholderRegex = RegExp(
    r'\[Image:([^\]]+)\]',
    caseSensitive: false,
  );
  final allImages = <QuizImageAsset>[...question.images, ...?option?.images];
  final imageById = {
    for (final image in allImages)
      if (image.id.trim().isNotEmpty) image.id.trim(): image,
  };

  for (final match in imagePlaceholderRegex.allMatches(raw)) {
    final id = _asText(match.group(1));
    final asset = imageById[id];
    if (asset == null) {
      continue;
    }
    final normalized = _normalizeAssetUrl(asset.path);
    if (normalized.isNotEmpty) {
      urls.add(normalized);
    }
  }

  for (final image in allImages) {
    final normalized = _normalizeAssetUrl(image.path);
    if (normalized.isNotEmpty) {
      urls.add(normalized);
    }
  }

  return urls.toList();
}

String _normalizeAssetUrl(String path) {
  final value = path.trim();
  if (value.isEmpty) {
    return '';
  }

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  if (value.startsWith('//')) {
    return 'https:$value';
  }

  final base = ApiConfig.webBaseUrl;
  if (value.startsWith('/')) {
    return '$base$value';
  }

  return '$base/$value';
}

String _stripHtml(String value) {
  if (value.trim().isEmpty) {
    return '';
  }

  var output = value;
  output = output
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  final lines = output
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return lines.join('\n');
}

String _asText(dynamic value) => (value ?? '').toString().trim();
