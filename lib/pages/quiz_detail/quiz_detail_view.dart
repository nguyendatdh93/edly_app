import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/course_detail/course_detail_repository.dart';
import 'package:edupen/pages/course_detail/course_detail_view.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_controller.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edupen/pages/quiz_detail/quiz_result_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/quiz_room_router.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QuizDetailView extends StatefulWidget {
  const QuizDetailView({super.key, required this.quizId});

  final String quizId;

  @override
  State<QuizDetailView> createState() => _QuizDetailViewState();
}

class _QuizDetailViewState extends State<QuizDetailView> {
  late final QuizDetailController _controller;
  final GlobalKey _historySectionKey = GlobalKey();

  bool _isOpeningRoom = false;
  bool _isLoadingCourseDetail = false;
  String? _courseDetailError;
  String? _loadedCourseKey;
  String? _loadingCourseKey;
  String? _queuedCourseKey;
  CourseDetailData? _courseDetail;

  @override
  void initState() {
    super.initState();
    _controller = QuizDetailController();
    _reloadAll();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reloadAll({bool forceCourse = false}) async {
    await _controller.load(widget.quizId);

    final current = _controller.data;
    if (current == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCourseDetail = false;
        _courseDetailError = null;
        _loadedCourseKey = null;
        _loadingCourseKey = null;
        _queuedCourseKey = null;
        _courseDetail = null;
      });
      return;
    }

    await _loadCourseDetail(current, force: forceCourse);
  }

  void _scheduleCourseDetailLoad(QuizDetailData data) {
    final courseKey = _courseKey(data.course);
    if (courseKey == null || courseKey.isEmpty) {
      return;
    }
    if (_loadedCourseKey == courseKey || _loadingCourseKey == courseKey) {
      return;
    }
    if (_queuedCourseKey == courseKey) {
      return;
    }

    _queuedCourseKey = courseKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_queuedCourseKey == courseKey) {
        _queuedCourseKey = null;
      }
      _loadCourseDetail(data);
    });
  }

  Future<void> _loadCourseDetail(
    QuizDetailData data, {
    bool force = false,
  }) async {
    final course = data.course;
    if (course == null || course.id.isEmpty) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCourseDetail = false;
        _courseDetailError = null;
        _loadedCourseKey = null;
        _loadingCourseKey = null;
        _courseDetail = null;
      });
      return;
    }

    final courseKey = _courseKey(course);
    if (courseKey == null || courseKey.isEmpty) {
      return;
    }

    if (!force) {
      if (_loadingCourseKey == courseKey) {
        return;
      }
      if (_loadedCourseKey == courseKey && _courseDetail != null) {
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingCourseDetail = true;
        _loadingCourseKey = courseKey;
        if (_loadedCourseKey != courseKey) {
          _courseDetail = null;
        }
        if (force || _loadedCourseKey != courseKey) {
          _courseDetailError = null;
        }
      });
    }

    try {
      final detail = await CourseDetailRepository.instance.fetchCourseDetail(
        course: _toHomeCourseItem(course),
        sourceLabel: 'quiz_detail',
      );

      if (!mounted || _loadingCourseKey != courseKey) {
        return;
      }

      setState(() {
        _courseDetail = detail;
        _courseDetailError = null;
        _loadedCourseKey = courseKey;
      });
    } on AppException catch (error) {
      if (!mounted || _loadingCourseKey != courseKey) {
        return;
      }

      setState(() {
        _courseDetail = null;
        _courseDetailError = error.message;
        _loadedCourseKey = courseKey;
      });
    } finally {
      if (mounted && _loadingCourseKey == courseKey) {
        setState(() {
          _isLoadingCourseDetail = false;
          _loadingCourseKey = null;
        });
      }
    }
  }

  String? _courseKey(QuizCourseSummary? course) {
    if (course == null || course.id.isEmpty) {
      return null;
    }

    return course.id;
  }

  HomeCourseItem _toHomeCourseItem(QuizCourseSummary course) {
    final safeSlug = course.slug.isNotEmpty ? course.slug : 'course';
    final safeTitle = course.title.isNotEmpty ? course.title : 'Khóa học';

    return HomeCourseItem(
      id: course.id,
      publicId: course.publicId.isNotEmpty ? course.publicId : course.id,
      slug: safeSlug,
      title: safeTitle,
      description: safeTitle,
    );
  }

  Future<void> _openQuizRoom() async {
    if (_isOpeningRoom) {
      return;
    }

    setState(() {
      _isOpeningRoom = true;
    });

    try {
      final room = await QuizDetailRepository.instance.fetchQuizRoom(
        widget.quizId,
      );

      if (!mounted) {
        return;
      }
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => buildQuizRoomByVariant(room)),
      );

      if (!mounted) {
        return;
      }

      if (completed == true) {
        await _reloadAll();
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningRoom = false;
        });
      }
    }
  }

  Future<void> _purchaseQuiz(QuizDetailData data) async {
    final courseId = data.course?.id;
    if (courseId == null || courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không xác định được khóa học của đề thi.'),
        ),
      );
      return;
    }

    final result = await _controller.purchaseByBalance(
      quizId: data.quiz.id,
      courseId: courseId,
    );

    if (!mounted || result == null) {
      return;
    }

    await AuthRepository.instance.refreshCurrentUser();

    final latest = _controller.data;
    if (latest != null) {
      await _loadCourseDetail(latest, force: true);
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  void _downloadQuiz(QuizDetailData data) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng tải xuống đang được đồng bộ từ web backend.'),
      ),
    );
  }

  Future<void> _openHistoryResult(
    QuizDetailData data,
    QuizHistoryItem item,
  ) async {
    final resultId = item.id.isNotEmpty ? item.id : item.uuid;
    if (resultId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy mã kết quả để mở.')),
      );
      return;
    }

    try {
      final result = await QuizDetailRepository.instance.fetchResult(
        resultId,
        quizId: data.quiz.id,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizResultView(
            result: result,
            quizName: data.quiz.name,
            questionCount: data.quiz.questionCount,
          ),
        ),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openCourseDetail(QuizDetailData data) async {
    final course = data.course;
    if (course == null || course.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy thông tin khóa học.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: _toHomeCourseItem(course),
          gradient: const [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
          accentColor: QuizDetailPalette.primary,
          sourceLabel: 'quiz_detail',
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAll(forceCourse: true);
  }

  Future<void> _openRelatedQuiz(String quizId) async {
    final targetQuizId = quizId.trim();
    if (targetQuizId.isEmpty) {
      return;
    }

    final currentQuizId = _controller.data?.quiz.id ?? widget.quizId;
    if (currentQuizId == targetQuizId) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizDetailView(quizId: targetQuizId),
      ),
    );

    if (mounted) {
      await _reloadAll();
    }
  }

  Future<void> _scrollToHistory() async {
    final targetContext = _historySectionKey.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  List<_RelatedQuizSection> _buildRelatedSections(QuizDetailData data) {
    final detail = _courseDetail;
    if (detail == null) {
      return const [];
    }

    final rows = <_RelatedQuizSection>[];
    for (final section in detail.sections) {
      final quizzes = <_RelatedQuizItem>[];

      for (final item in section.items) {
        if (!item.isQuiz) {
          continue;
        }

        final isCurrent = item.id == data.quiz.id;
        final canOpen = isCurrent || item.canOpen;

        quizzes.add(
          _RelatedQuizItem(
            id: item.id,
            title: item.title,
            isCurrent: isCurrent,
            canOpen: canOpen,
            badge: item.badgeLabel ?? item.metaLabel,
          ),
        );
      }

      if (quizzes.isEmpty) {
        continue;
      }

      rows.add(
        _RelatedQuizSection(
          id: section.id,
          title: section.title,
          isCurrent: quizzes.any((item) => item.isCurrent),
          quizzes: quizzes,
        ),
      );
    }

    return rows;
  }

  String? _resolveCurrentSectionTitle(List<_RelatedQuizSection> sections) {
    for (final section in sections) {
      if (section.isCurrent) {
        return section.title;
      }
    }
    return null;
  }

  int _resolveTotalRelatedQuiz(List<_RelatedQuizSection> sections) {
    var total = 0;
    for (final section in sections) {
      total += section.quizzes.length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;

        if (data != null) {
          _scheduleCourseDetailLoad(data);
        }

        final isRefreshing = _controller.isLoading || _isLoadingCourseDetail;

        return Scaffold(
          backgroundColor: QuizDetailPalette.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Chi tiết đề thi',
              style: TextStyle(
                color: QuizDetailPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            bottom: isRefreshing
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: _controller.isLoading && data == null
              ? const Center(child: CircularProgressIndicator())
              : data == null
              ? _ErrorState(
                  message:
                      _controller.errorMessage ??
                      'Không tải được dữ liệu đề thi.',
                  onRetry: () => _reloadAll(forceCourse: true),
                )
              : RefreshIndicator(
                  onRefresh: () => _reloadAll(forceCourse: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1080;
                      final relatedSections = _buildRelatedSections(data);
                      final currentSectionTitle = _resolveCurrentSectionTitle(
                        relatedSections,
                      );
                      final totalRelatedQuiz = _resolveTotalRelatedQuiz(
                        relatedSections,
                      );

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 20 : 16,
                          16,
                          isWide ? 20 : 16,
                          24,
                        ),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1240),
                              child: Column(
                                children: [
                                  _HeroSection(
                                    data: data,
                                    courseTitle: data.course?.title ?? '',
                                    isBusy:
                                        _controller.isPurchasing ||
                                        _isOpeningRoom,
                                    onOpenRoom: _openQuizRoom,
                                    onPurchase: () => _purchaseQuiz(data),
                                    onDownload: () => _downloadQuiz(data),
                                    onOpenHistory: data.history.isEmpty
                                        ? null
                                        : _scrollToHistory,
                                  ),
                                  const SizedBox(height: 14),
                                  _OverviewStats(data: data),
                                  const SizedBox(height: 14),
                                  if (isWide)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            children: [
                                              if (data.course != null) ...[
                                                _CourseContextCard(
                                                  courseTitle:
                                                      data.course?.title ?? '',
                                                  currentSectionTitle:
                                                      currentSectionTitle,
                                                  totalQuizCount:
                                                      totalRelatedQuiz,
                                                  onOpenCourse: () =>
                                                      _openCourseDetail(data),
                                                ),
                                                const SizedBox(height: 14),
                                              ],
                                              _ModuleStructureCard(data: data),
                                              const SizedBox(height: 14),
                                              _HistoryCard(
                                                key: _historySectionKey,
                                                data: data,
                                                onOpenResult: (item) =>
                                                    _openHistoryResult(
                                                      data,
                                                      item,
                                                    ),
                                              ),
                                              const SizedBox(height: 14),
                                              _RelatedQuizCard(
                                                sections: relatedSections,
                                                isLoading:
                                                    _isLoadingCourseDetail,
                                                errorMessage:
                                                    _courseDetailError,
                                                totalQuizCount:
                                                    totalRelatedQuiz,
                                                onRetry: () =>
                                                    _loadCourseDetail(
                                                      data,
                                                      force: true,
                                                    ),
                                                onOpenQuiz: _openRelatedQuiz,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: _ProgressCard(
                                            history: data.history,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      children: [
                                        if (data.course != null) ...[
                                          _CourseContextCard(
                                            courseTitle:
                                                data.course?.title ?? '',
                                            currentSectionTitle:
                                                currentSectionTitle,
                                            totalQuizCount: totalRelatedQuiz,
                                            onOpenCourse: () =>
                                                _openCourseDetail(data),
                                          ),
                                          const SizedBox(height: 14),
                                        ],
                                        _HistoryCard(
                                          key: _historySectionKey,
                                          data: data,
                                          onOpenResult: (item) =>
                                              _openHistoryResult(data, item),
                                        ),
                                        const SizedBox(height: 14),
                                        _RelatedQuizCard(
                                          sections: relatedSections,
                                          isLoading: _isLoadingCourseDetail,
                                          errorMessage: _courseDetailError,
                                          totalQuizCount: totalRelatedQuiz,
                                          onRetry: () => _loadCourseDetail(
                                            data,
                                            force: true,
                                          ),
                                          onOpenQuiz: _openRelatedQuiz,
                                        ),
                                        const SizedBox(height: 14),
                                        _ModuleStructureCard(data: data),
                                        const SizedBox(height: 14),
                                        _ProgressCard(history: data.history),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
        );
      },
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.data,
    required this.courseTitle,
    required this.isBusy,
    required this.onOpenRoom,
    required this.onPurchase,
    required this.onDownload,
    required this.onOpenHistory,
  });

  final QuizDetailData data;
  final String courseTitle;
  final bool isBusy;
  final Future<void> Function() onOpenRoom;
  final Future<void> Function() onPurchase;
  final VoidCallback onDownload;
  final Future<void> Function()? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final quiz = data.quiz;
    final hasAccess = data.access.canAccess;
    final timeLabel = _formatTime(_displayMinutes(quiz));
    final dateLabel = quiz.updatedAt == null
        ? '-'
        : DateFormat('dd/MM/yyyy').format(quiz.updatedAt!);
    final statusLabel = hasAccess ? 'Đã mua' : 'Chưa mua';
    final statusColor = hasAccess
        ? const Color(0xFF86EFAC)
        : const Color(0xFFFDE68A);
    final description = _stripHtml(quiz.description);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (courseTitle.trim().isNotEmpty)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFFBFDBFE),
                  size: 16,
                ),
                Text(
                  courseTitle.trim(),
                  style: const TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          if (courseTitle.trim().isNotEmpty) const SizedBox(height: 8),
          Text(
            quiz.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 26,
              height: 1.2,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFE2E8F0), height: 1.4),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MetaText(label: 'Thời gian', value: timeLabel),
              _MetaText(label: 'Cập nhật', value: dateLabel),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trạng thái: ',
                    style: TextStyle(color: Color(0xFFC7D2FE)),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasAccess)
                FilledButton.icon(
                  onPressed: isBusy ? null : onOpenRoom,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    quiz.isExamMode ? 'Bắt đầu thi' : 'Bắt đầu làm bài',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: isBusy ? null : onPurchase,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: const Text('Mua ngay'),
                ),
              if (hasAccess && onOpenHistory != null)
                FilledButton.icon(
                  onPressed: isBusy ? null : onOpenHistory,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Xem lịch sử'),
                ),
              if (hasAccess)
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onDownload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Tải xuống'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.data});

  final QuizDetailData data;

  @override
  Widget build(BuildContext context) {
    final quiz = data.quiz;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cells = [
            _OverviewCell(label: 'Câu hỏi', value: '${quiz.questionCount}'),
            _OverviewCell(
              label: 'Thời gian',
              value: _formatTime(_displayMinutes(quiz)),
            ),
            _OverviewCell(
              label: 'Loại',
              value: data.room.isExam ? 'Bài thi' : 'Bài tập',
            ),
            _OverviewCell(label: 'Lượt thi', value: '${data.history.length}'),
          ];

          final useWrap = constraints.maxWidth < 700;
          if (!useWrap) {
            return Row(
              children: [
                for (final cell in cells)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: cell,
                    ),
                  ),
              ],
            );
          }

          final cellWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final cell in cells) SizedBox(width: cellWidth, child: cell),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: QuizDetailPalette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CourseContextCard extends StatelessWidget {
  const _CourseContextCard({
    required this.courseTitle,
    required this.currentSectionTitle,
    required this.totalQuizCount,
    required this.onOpenCourse,
  });

  final String courseTitle;
  final String? currentSectionTitle;
  final int totalQuizCount;
  final Future<void> Function() onOpenCourse;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Đề này thuộc khóa học',
            style: TextStyle(
              color: QuizDetailPalette.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            courseTitle,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (currentSectionTitle != null &&
                  currentSectionTitle!.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: QuizDetailPalette.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Phần: $currentSectionTitle',
                      style: const TextStyle(
                        color: QuizDetailPalette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              if (totalQuizCount > 0)
                _Tag(
                  text: '$totalQuizCount quiz',
                  bg: const Color(0xFFDBEAFE),
                  color: const Color(0xFF1D4ED8),
                ),
              FilledButton.icon(
                onPressed: onOpenCourse,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Xem toàn bộ khóa học'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelatedQuizCard extends StatelessWidget {
  const _RelatedQuizCard({
    required this.sections,
    required this.isLoading,
    required this.errorMessage,
    required this.totalQuizCount,
    required this.onRetry,
    required this.onOpenQuiz,
  });

  final List<_RelatedQuizSection> sections;
  final bool isLoading;
  final String? errorMessage;
  final int totalQuizCount;
  final Future<void> Function() onRetry;
  final Future<void> Function(String quizId) onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Các bài kiểm tra khác trong khóa học',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (totalQuizCount > 0)
                _Tag(
                  text: '$totalQuizCount quiz',
                  bg: const Color(0xFFDBEAFE),
                  color: const Color(0xFF1E40AF),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (sections.isEmpty && (errorMessage ?? '').isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: QuizDetailPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tải lại danh sách'),
                ),
              ],
            )
          else if (sections.isEmpty)
            const Text(
              'Chưa có dữ liệu quiz liên quan trong khóa học.',
              style: TextStyle(color: QuizDetailPalette.textSecondary),
            )
          else
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _RelatedSectionBlock(
                  section: section,
                  onOpenQuiz: onOpenQuiz,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RelatedSectionBlock extends StatelessWidget {
  const _RelatedSectionBlock({required this.section, required this.onOpenQuiz});

  final _RelatedQuizSection section;
  final Future<void> Function(String quizId) onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    final titleColor = section.isCurrent
        ? const Color(0xFF1D4ED8)
        : QuizDetailPalette.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📘', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                section.title,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (section.isCurrent)
              _Tag(
                text: 'Đang học',
                bg: const Color(0xFFDBEAFE),
                color: const Color(0xFF1D4ED8),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...section.quizzes.map(
          (quiz) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: quiz.isCurrent
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: quiz.isCurrent
                      ? const Color(0xFF93C5FD)
                      : QuizDetailPalette.border,
                  width: quiz.isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (quiz.isCurrent)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                quiz.title,
                                style: TextStyle(
                                  color: QuizDetailPalette.textPrimary,
                                  fontWeight: quiz.isCurrent
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((quiz.badge ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            quiz.badge!,
                            style: const TextStyle(
                              color: QuizDetailPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (quiz.isCurrent)
                    const Text(
                      'Hiện tại',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else if (quiz.canOpen)
                    FilledButton(
                      onPressed: () => onOpenQuiz(quiz.id),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Xem ngay'),
                    )
                  else
                    const _Tag(
                      text: 'Bị khóa',
                      bg: Color(0xFFFFF7ED),
                      color: Color(0xFFB45309),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleStructureCard extends StatelessWidget {
  const _ModuleStructureCard({required this.data});

  final QuizDetailData data;

  @override
  Widget build(BuildContext context) {
    final modules = data.quiz.modules;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cấu trúc đề thi',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (modules.isEmpty)
            const Text(
              'Không có dữ liệu module cho đề thi này.',
              style: TextStyle(color: QuizDetailPalette.textSecondary),
            )
          else
            ...modules.map(
              (module) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuizDetailPalette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          module.name,
                          style: const TextStyle(
                            color: QuizDetailPalette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (module.defaultQuestionCount > 0)
                        _Tag(
                          text: '${module.defaultQuestionCount} câu',
                          bg: const Color(0xFFECFDF3),
                          color: const Color(0xFF166534),
                        ),
                      if (module.minutes > 0) ...[
                        const SizedBox(width: 8),
                        _Tag(
                          text: '${module.minutes} phút',
                          bg: const Color(0xFFFFFBEB),
                          color: const Color(0xFFB45309),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.bg, required this.color});

  final String text;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.history});

  final List<QuizHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final maxScoreItem = _highestScore(history);
    final average = _averageScore(history);
    final lastDate = _latestDate(history);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến trình của bạn',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điểm cao nhất',
                  style: TextStyle(color: QuizDetailPalette.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${maxScoreItem.$1}',
                  style: const TextStyle(
                    color: QuizDetailPalette.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (maxScoreItem.$2 != null)
                  Text(
                    'ngày ${DateFormat('dd/MM/yyyy').format(maxScoreItem.$2!)}',
                    style: const TextStyle(
                      color: QuizDetailPalette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.replay_rounded,
            label: 'Số lần làm bài',
            value: '${history.length} lần',
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.star_rounded,
            label: 'Điểm trung bình',
            value: '$average',
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.history_rounded,
            label: 'Lần làm gần nhất',
            value: lastDate,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    super.key,
    required this.data,
    required this.onOpenResult,
  });

  final QuizDetailData data;
  final Future<void> Function(QuizHistoryItem item) onOpenResult;

  @override
  Widget build(BuildContext context) {
    final history = data.history;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lịch sử thi',
                  style: TextStyle(
                    color: QuizDetailPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (history.isNotEmpty)
                Text(
                  '${history.length} lượt',
                  style: const TextStyle(
                    color: QuizDetailPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text(
              'Bạn chưa có lần làm bài nào.',
              style: TextStyle(color: QuizDetailPalette.textSecondary),
            )
          else
            ...history.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final score = _resolveHistoryScore(item);
              final date = item.createdAt == null
                  ? '-'
                  : DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt!);
              final correct = item.score.correct;
              final wrong = item.score.wrong;
              final displayIndex = history.length - index;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: QuizDetailPalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$displayIndex',
                          style: const TextStyle(
                            color: QuizDetailPalette.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            date,
                            style: const TextStyle(
                              color: QuizDetailPalette.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const _Tag(
                          text: 'Hoàn thành',
                          bg: Color(0xFFECFDF3),
                          color: Color(0xFF166534),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Điểm: $score  •  Đúng: $correct  •  Sai: $wrong',
                      style: const TextStyle(
                        color: QuizDetailPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => onOpenResult(item),
                        child: const Text('Chi tiết'),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: QuizDetailPalette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: QuizDetailPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: Color(0xFFCBD5E1))),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: QuizDetailPalette.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _RelatedQuizSection {
  const _RelatedQuizSection({
    required this.id,
    required this.title,
    required this.isCurrent,
    required this.quizzes,
  });

  final String id;
  final String title;
  final bool isCurrent;
  final List<_RelatedQuizItem> quizzes;
}

class _RelatedQuizItem {
  const _RelatedQuizItem({
    required this.id,
    required this.title,
    required this.isCurrent,
    required this.canOpen,
    required this.badge,
  });

  final String id;
  final String title;
  final bool isCurrent;
  final bool canOpen;
  final String? badge;
}

(int, DateTime?) _highestScore(List<QuizHistoryItem> history) {
  if (history.isEmpty) {
    return (0, null);
  }

  var bestScore = -1;
  DateTime? bestDate;
  for (final item in history) {
    final score = _resolveHistoryScore(item);
    if (score > bestScore) {
      bestScore = score;
      bestDate = item.createdAt;
    }
  }

  return (bestScore < 0 ? 0 : bestScore, bestDate);
}

int _averageScore(List<QuizHistoryItem> history) {
  if (history.isEmpty) {
    return 0;
  }

  var total = 0;
  for (final item in history) {
    total += _resolveHistoryScore(item);
  }

  return (total / history.length).round();
}

String _latestDate(List<QuizHistoryItem> history) {
  final dates = history
      .map((item) => item.createdAt)
      .whereType<DateTime>()
      .toList();
  if (dates.isEmpty) {
    return '-';
  }
  dates.sort((a, b) => b.compareTo(a));
  return DateFormat('dd/MM/yyyy').format(dates.first);
}

int _resolveHistoryScore(QuizHistoryItem item) {
  if (item.type == 'module' || item.submissionType == 'exam') {
    return item.score.inferredTotalScore;
  }
  return item.score.totalScore;
}

int _displayMinutes(QuizSummary quiz) {
  if (quiz.modules.isNotEmpty) {
    var total = 0;
    for (final module in quiz.modules) {
      if (module.minutes > 0) {
        total += module.minutes;
      }
    }
    if (total > 0) {
      return total;
    }
  }
  return quiz.minute;
}

String _formatTime(int minutes) {
  if (minutes <= 0) {
    return 'Không giới hạn';
  }

  final hour = minutes ~/ 60;
  final remain = minutes % 60;
  if (hour > 0) {
    return '$hour giờ ${remain.toString()} phút';
  }
  return '$minutes phút';
}

String _stripHtml(String raw) {
  var normalized = raw.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  normalized = normalized.replaceAll(RegExp(r'<[^>]*>'), ' ');
  normalized = normalized.replaceAll('&nbsp;', ' ');
  normalized = normalized.replaceAll('&amp;', '&');
  normalized = normalized.replaceAll('&lt;', '<');
  normalized = normalized.replaceAll('&gt;', '>');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  return normalized.trim();
}
