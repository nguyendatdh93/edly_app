import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_constants.dart';
import 'package:edupen/pages/course_detail/course_detail_lecture_view.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/course_detail/course_detail_repository.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:edupen/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CourseDetailView extends StatefulWidget {
  const CourseDetailView({
    super.key,
    required this.course,
    required this.gradient,
    required this.accentColor,
    required this.sourceLabel,
    this.currentDockTab,
    this.relatedCourses = const [],
  });

  final HomeCourseItem course;
  final List<Color> gradient;
  final Color accentColor;
  final String sourceLabel;
  final LearningDockTab? currentDockTab;
  final List<HomeCourseItem> relatedCourses;

  @override
  State<CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<CourseDetailView> {
  late final CourseDetailData _fallbackData;
  late Future<CourseDetailData> _detailFuture;
  bool _isPurchasingByBalance = false;
  final GlobalKey _curriculumSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fallbackData = CourseDetailData.fallback(
      course: widget.course,
      sourceLabel: widget.sourceLabel,
      fallbackRelatedCourses: widget.relatedCourses,
    );
    _detailFuture = _loadDetail();
  }

  Future<CourseDetailData> _loadDetail() {
    return CourseDetailRepository.instance.fetchCourseDetail(
      course: widget.course,
      sourceLabel: widget.sourceLabel,
      fallbackRelatedCourses: widget.relatedCourses,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _detailFuture = _loadDetail();
    });
    await _detailFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CourseDetailData>(
      future: _detailFuture,
      initialData: _fallbackData,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _fallbackData;
        final isLoading =
            snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasError;
        final errorMessage = snapshot.hasError
            ? _messageFromError(snapshot.error)
            : null;

        return _CourseDetailScaffold(
          data: data,
          accentColor: widget.accentColor,
          currentTab: _resolveDockTab(),
          isLoading: isLoading,
          isPurchasing: _isPurchasingByBalance,
          errorMessage: errorMessage,
          curriculumSectionKey: _curriculumSectionKey,
          onRetry: _reload,
          onCurriculumTap: _scrollToCurriculum,
          onBalancePurchaseTap: () => _purchaseByBalance(data),
          onLearningItemTap: (item) => _openLearningItem(data, item),
        );
      },
    );
  }

  Future<void> _scrollToCurriculum() async {
    final targetContext = _curriculumSectionKey.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeInOutCubic,
      alignment: 0.02,
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return CourseDetailCopy.genericErrorMessage;
  }

  LearningDockTab _resolveDockTab() {
    if (widget.currentDockTab != null) {
      return widget.currentDockTab!;
    }

    final signature = widget.sourceLabel.trim().toLowerCase();
    if (signature.contains('đã mua') ||
        signature.contains('da mua') ||
        signature.contains('purchased')) {
      return LearningDockTab.purchasedCourses;
    }

    return LearningDockTab.home;
  }

  Future<void> _purchaseByBalance(CourseDetailData data) async {
    if (_isPurchasingByBalance) {
      return;
    }

    final purchase = data.purchase;
    if (!purchase.canPurchase) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khóa học này hiện không cần thanh toán.'),
        ),
      );
      return;
    }

    setState(() {
      _isPurchasingByBalance = true;
    });

    try {
      final result = await CourseDetailRepository.instance
          .purchaseCourseByBalance(detail: data);
      await AuthRepository.instance.refreshCurrentUser();
      await _reload();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
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
          _isPurchasingByBalance = false;
        });
      }
    }
  }

  Future<void> _openLearningItem(
    CourseDetailData data,
    CourseDetailLearningItem item,
  ) async {
    if (item.isDraft) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nội dung đang ở trạng thái nháp và chưa thể truy cập.',
          ),
        ),
      );
      return;
    }

    if (item.isQuiz) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              QuizDetailView(quizId: item.id, currentTab: _resolveDockTab()),
        ),
      );
      if (mounted) {
        await _reload();
      }
      return;
    }

    if (!item.canOpen) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn chưa có quyền truy cập nội dung này. Hãy mua gói hoặc quyền tương ứng.',
          ),
        ),
      );
      return;
    }

    if (!item.isLecture) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nội dung này chưa hỗ trợ trên mobile app.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailLectureView(
          initialItem: item,
          courseSlug: data.courseSlug,
          courseTitle: data.hero.title,
          sections: data.sections,
          currentDockTab: _resolveDockTab(),
        ),
      ),
    );
    if (mounted) {
      await _reload();
    }
  }
}

class _CourseDetailScaffold extends StatelessWidget {
  const _CourseDetailScaffold({
    required this.data,
    required this.accentColor,
    required this.currentTab,
    required this.isLoading,
    required this.isPurchasing,
    required this.errorMessage,
    required this.curriculumSectionKey,
    required this.onRetry,
    required this.onCurriculumTap,
    required this.onBalancePurchaseTap,
    required this.onLearningItemTap,
  });

  final CourseDetailData data;
  final Color accentColor;
  final LearningDockTab currentTab;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;
  final GlobalKey curriculumSectionKey;
  final Future<void> Function() onRetry;
  final Future<void> Function() onCurriculumTap;
  final Future<void> Function() onBalancePurchaseTap;
  final Future<void> Function(CourseDetailLearningItem item) onLearningItemTap;

  @override
  Widget build(BuildContext context) {
    final shouldShowInfoBanner =
        isLoading || errorMessage != null || !data.isFromApi;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      bottomNavigationBar: LearningDockBar(currentTab: currentTab),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: onRetry,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _HeroSection(
                          data: data,
                          accentColor: accentColor,
                          isPurchasing: isPurchasing,
                          onBalanceTap: onBalancePurchaseTap,
                          onCurriculumTap: onCurriculumTap,
                          onPreviewTap: onLearningItemTap,
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shouldShowInfoBanner) ...[
                                  _InfoBanner(
                                    message:
                                        errorMessage ??
                                        (isLoading
                                            ? CourseDetailCopy.loadingMessage
                                            : CourseDetailCopy.fallbackMessage),
                                    accentColor: errorMessage != null
                                        ? CourseDetailPalette.warning
                                        : CourseDetailPalette.info,
                                    actionLabel: errorMessage != null
                                        ? 'Thử lại'
                                        : null,
                                    onAction: errorMessage != null
                                        ? onRetry
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                _SectionCard(
                                  title: 'Giới thiệu về khóa học',
                                  child: _ExpandableOverview(
                                    text: data.overview,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                KeyedSubtree(
                                  key: curriculumSectionKey,
                                  child: _SectionCard(
                                    title: 'Nội dung khóa học',
                                    headerPadding: const EdgeInsets.fromLTRB(
                                      0,
                                      0,
                                      0,
                                      12,
                                    ),
                                    isPlain: true,
                                    bodyPadding: EdgeInsets.zero,
                                    trailing: Text(
                                      '${data.totalSections} phần • ${data.totalLectures} bài giảng • ${data.totalQuizzes} đề thi',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: CourseDetailPalette
                                                .textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    child: data.sections.isEmpty
                                        ? _EmptyLearningState(
                                            message: data.isFromApi
                                                ? 'Khóa học này chưa có section hoặc item để hiển thị trên mobile.'
                                                : 'Danh sách phần học sẽ hiện khi API chi tiết tải xong.',
                                          )
                                        : Column(
                                            children: List.generate(
                                              data.sections.length,
                                              (index) => Padding(
                                                padding: EdgeInsets.only(
                                                  bottom:
                                                      index ==
                                                          data.sections.length -
                                                              1
                                                      ? 0
                                                      : 14,
                                                ),
                                                child: _CourseSectionTile(
                                                  index: index + 1,
                                                  section: data.sections[index],
                                                  accentColor: accentColor,
                                                  isExam: data.isExam,
                                                  onItemTap: onLearningItemTap,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.accentColor,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color accentColor;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CourseDetailPalette.textPrimary,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(onPressed: () => onAction!(), child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.data,
    required this.accentColor,
    required this.isPurchasing,
    required this.onBalanceTap,
    required this.onCurriculumTap,
    required this.onPreviewTap,
  });

  final CourseDetailData data;
  final Color accentColor;
  final bool isPurchasing;
  final Future<void> Function() onBalanceTap;
  final Future<void> Function() onCurriculumTap;
  final Future<void> Function(CourseDetailLearningItem item) onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final hero = data.hero;
    final previewItem = data.firstAccessibleItem;
    final summary = _toPlainText(hero.summary);
    final isPurchased = data.isPurchased || hero.isPurchased;
    final backgroundColors = data.isExam
        ? const [Color(0xFF18335F), Color(0xFF0E1D37), Color(0xFF0D172A)]
        : const [Color(0xFF2E3139), Color(0xFF1F2937), Color(0xFF111827)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColors,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chi tiết khóa học',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              hero.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary.isNotEmpty
                  ? summary
                  : 'Thông tin chi tiết khóa học đang được cập nhật.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFD5C7C7),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroStatChip(
                  icon: Icons.dashboard_customize_rounded,
                  label: '${data.totalSections} phần',
                ),
                _HeroStatChip(
                  icon: Icons.assignment_rounded,
                  label: '${data.totalQuizzes} đề thi',
                ),
                if (hero.totalHoursLabel != null &&
                    hero.totalHoursLabel!.isNotEmpty)
                  _HeroStatChip(
                    icon: Icons.schedule_rounded,
                    label: hero.totalHoursLabel!,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (hero.authorName != null && hero.authorName!.isNotEmpty)
                  _HeroMetaItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Tác giả: ${hero.authorName!}',
                  ),
                if (hero.updatedAtLabel != null &&
                    hero.updatedAtLabel!.isNotEmpty)
                  _HeroMetaItem(
                    icon: Icons.error_outline_rounded,
                    label: 'Cập nhật ${hero.updatedAtLabel!}',
                  ),
                if (hero.languageLabel != null &&
                    hero.languageLabel!.isNotEmpty)
                  _HeroMetaItem(
                    icon: Icons.language_rounded,
                    label: hero.languageLabel!,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => onCurriculumTap(),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                backgroundColor: Colors.white.withValues(alpha: 0.17),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                ),
              ),
              label: const Text(
                'Nội dung khóa học',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isPurchased || hero.progress > 0) ...[
              const SizedBox(height: 16),
              _ProgressCard(
                progress: hero.progress,
                detail:
                    hero.completedLessons != null && hero.totalLessons != null
                    ? '${hero.completedLessons}/${hero.totalLessons} nội dung hoàn thành'
                    : 'Tiến độ học đang được đồng bộ từ tài khoản của bạn',
                accentColor: accentColor,
              ),
            ],
            const SizedBox(height: 16),
            _PurchaseCard(
              purchase: data.purchase,
              thumbnailUrl: hero.thumbnailUrl,
              isPurchased: isPurchased,
              isPurchasing: isPurchasing,
              onBalanceTap: onBalanceTap,
              onPreviewTap: previewItem == null
                  ? null
                  : () => onPreviewTap(previewItem),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetaItem extends StatelessWidget {
  const _HeroMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE5E7EB)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFE5E7EB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.detail,
    required this.accentColor,
  });

  final int progress;
  final String detail;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tiến độ học tập',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$progress%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 100) / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation<Color>(
                accentColor.withValues(alpha: 0.96),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({
    required this.purchase,
    required this.thumbnailUrl,
    required this.isPurchased,
    required this.isPurchasing,
    required this.onBalanceTap,
    this.onPreviewTap,
  });

  final CourseDetailPurchaseInfo purchase;
  final String? thumbnailUrl;
  final bool isPurchased;
  final bool isPurchasing;
  final Future<void> Function() onBalanceTap;
  final Future<void> Function()? onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.decimalPattern('vi_VN');
    final currentPrice = purchase.currentPrice;
    final originalPrice = purchase.originalPrice;
    final currentPriceLabel =
        purchase.currentPriceLabel ??
        (currentPrice != null
            ? '${currencyFormat.format(currentPrice)}đ'
            : null);
    final originalPriceLabel =
        purchase.originalPriceLabel ??
        (originalPrice != null
            ? '${currencyFormat.format(originalPrice)}đ'
            : null);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 2 / 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: const Color(0xFFE5E7EB));
                      },
                    ),
                    if (onPreviewTap != null)
                      Material(
                        color: Colors.black.withValues(alpha: 0.2),
                        child: Center(
                          child: InkWell(
                            onTap: () => onPreviewTap!(),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isPurchased && currentPriceLabel != null) ...[
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Text(
                          currentPriceLabel,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: const Color(0xFFDC2626),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (purchase.hasDiscount && originalPriceLabel != null)
                          Text(
                            originalPriceLabel,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFF9CA3AF),
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thanh toán một lần',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isPurchased)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF15803D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Đã Mua Khóa Học',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFF15803D),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    )
                  else if (purchase.canPurchase) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isPurchasing ? null : () => onBalanceTap(),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isPurchasing) ...[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              isPurchasing
                                  ? 'ĐANG XỬ LÝ...'
                                  : 'ĐẶT MUA TRỌN BỘ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (onPreviewTap != null && !isPurchased) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => onPreviewTap!(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: Color(0xFFD6D3D1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          foregroundColor: const Color(0xFF1F2937),
                        ),
                        child: const Text(
                          'Xem thử bài học',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                  if (!isPurchased &&
                      currentPriceLabel == null &&
                      purchase.currentPrice != null &&
                      purchase.currentPrice! > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${currencyFormat.format(purchase.currentPrice)}₫',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.headerPadding = const EdgeInsets.all(18),
    this.bodyPadding = const EdgeInsets.fromLTRB(18, 0, 18, 18),
    this.isPlain = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry bodyPadding;
  final bool isPlain;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: isPlain
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFEAE7E1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: headerPadding,
            child: isPlain && trailing != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: title),
                      const SizedBox(height: 6),
                      trailing!,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _SectionTitle(title: title)),
                      if (trailing != null) ...[
                        const SizedBox(width: 12),
                        Flexible(child: trailing!),
                      ],
                    ],
                  ),
          ),
          Padding(padding: bodyPadding, child: child),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: CourseDetailPalette.textPrimary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CurriculumHeadline extends StatelessWidget {
  const _CurriculumHeadline({
    required this.totalSections,
    required this.totalLectures,
    required this.totalQuizzes,
  });

  final int totalSections;
  final int totalLectures;
  final int totalQuizzes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        _InlineChip(
          label: '$totalSections phần',
          backgroundColor: const Color(0xFFF5F3FF),
          foregroundColor: const Color(0xFF6D28D9),
        ),
        _InlineChip(
          label: '$totalLectures bài giảng',
          backgroundColor: const Color(0xFFECFDF5),
          foregroundColor: const Color(0xFF047857),
        ),
        _InlineChip(
          label: '$totalQuizzes đề thi',
          backgroundColor: const Color(0xFFEFF6FF),
          foregroundColor: const Color(0xFF1D4ED8),
        ),
      ],
    );
  }
}

class _ExpandableOverview extends StatefulWidget {
  const _ExpandableOverview({required this.text});

  final String text;

  @override
  State<_ExpandableOverview> createState() => _ExpandableOverviewState();
}

class _ExpandableOverviewState extends State<_ExpandableOverview> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = _toPlainText(widget.text);
    final canExpand = text.length > 220 || '\n'.allMatches(text).length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: !_expanded && canExpand ? 2 : null,
          overflow: !_expanded && canExpand ? TextOverflow.ellipsis : null,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CourseDetailPalette.textPrimary,
            height: 1.6,
          ),
        ),
        if (canExpand) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(_expanded ? 'Thu gọn' : 'Xem thêm'),
          ),
        ],
      ],
    );
  }
}

class _CourseSectionTile extends StatelessWidget {
  const _CourseSectionTile({
    required this.index,
    required this.section,
    required this.accentColor,
    required this.isExam,
    required this.onItemTap,
  });

  final int index;
  final CourseDetailSection section;
  final Color accentColor;
  final bool isExam;
  final Future<void> Function(CourseDetailLearningItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final isHidden = section.status.trim().toLowerCase() == 'hidden';
    final sectionBg = isHidden
        ? const Color(0xFFF8FAFC)
        : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: PageStorageKey('course-section-${section.id}'),
          tilePadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: index == 1,
          shape: const Border(),
          collapsedShape: const Border(),
          
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (section.isLocked)
                    Container(
                      margin: const EdgeInsets.only(left: 8, top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Đã khóa',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (section.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _toPlainText(section.description),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (section.videoCount > 0)
                    _InlineChip(
                      icon: Icons.play_circle_outline_rounded,
                      label: '${section.videoCount} video',
                      backgroundColor: const Color(0xFFFAF5FF),
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                  if (section.docxCount > 0)
                    _InlineChip(
                      icon: Icons.description_outlined,
                      label: '${section.docxCount} tài liệu',
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF334155),
                    ),
                  if (section.pdfCount > 0)
                    _InlineChip(
                      icon: Icons.picture_as_pdf_rounded,
                      label: '${section.pdfCount} PDF',
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                  if (section.quizCount > 0)
                    _InlineChip(
                      icon: Icons.assignment_outlined,
                      label: '${section.quizCount} quiz',
                      backgroundColor: const Color(0xFFDBEAFE),
                      foregroundColor: const Color(0xFF1D4ED8),
                    ),
                  if (section.durationLabel != null &&
                      section.durationLabel!.isNotEmpty)
                    _InlineChip(
                      icon: Icons.schedule_rounded,
                      label: section.durationLabel!,
                      backgroundColor: const Color(0xFFFFF7ED),
                      foregroundColor: const Color(0xFFEA580C),
                    ),
                  if (section.isLocked && section.price > 0)
                    _InlineChip(
                      icon: Icons.payments_outlined,
                      label: _formatVnd(section.price),
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFCFD),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              child: section.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _EmptyLearningState(
                        message:
                            'Section này chưa có bài học hoặc đề thi để hiển thị.',
                      ),
                    )
                  : Column(
                      children: List.generate(
                        section.items.length,
                        (itemIndex) => _TimelineLearningItem(
                          item: section.items[itemIndex],
                          index: itemIndex,
                          isLast: itemIndex == section.items.length - 1,
                          onTap: () => onItemTap(section.items[itemIndex]),
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
class _TimelineLearningItem extends StatelessWidget {
  const _TimelineLearningItem({
    required this.item,
    required this.index,
    required this.isLast,
    required this.onTap,
  });

  final CourseDetailLearningItem item;
  final int index;
  final bool isLast;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final toneColor = resolveCourseDetailTone(item.toneKey);
    final iconData = resolveCourseDetailIcon(item.iconKey);
    final isFree = item.price <= 0;

    final actionLabel = isFree
        ? (item.isQuiz ? 'Thi thử' : 'Xem')
        : (item.canOpen ? 'Học ngay' : 'Mở khóa');

    final actionBackground = isFree
        ? const Color(0xFFF97316)
        : (item.canOpen
            ? const Color(0xFF16A34A)
            : const Color(0xFF2563EB));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: toneColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: toneColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: 16,
                    color: toneColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: InkWell(
                onTap: () => onTap(),
                borderRadius: BorderRadius.circular(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Row(
                                children: [
                                 
                                  if (item.badgeLabel != null &&
                                      item.badgeLabel!.trim().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    _InlineChip(
                                      label: item.badgeLabel!,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF475569),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (item.isLocked)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InlineChip(
                          label: item.typeLabel,
                          backgroundColor: toneColor.withValues(alpha: 0.1),
                          foregroundColor: toneColor,
                        ),
                        if (item.questionCount != null &&
                            item.questionCount! > 0)
                          _InlineChip(
                            label: '${item.questionCount} câu hỏi',
                            backgroundColor: const Color(0xFFF8FAFC),
                            foregroundColor: const Color(0xFF334155),
                          ),
                        _InlineChip(
                          label: isFree ? 'Miễn phí' : _formatVnd(item.price),
                          backgroundColor: isFree
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          foregroundColor: isFree
                              ? const Color(0xFF15803D)
                              : const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.isQuiz
                                ? 'Làm bài để kiểm tra mức độ hiểu bài và luyện tập.'
                                : 'Mở nội dung để tiếp tục học trong section này.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () => onTap(),
                          style: FilledButton.styleFrom(
                            backgroundColor: actionBackground,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            actionLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
class _InlineChip extends StatelessWidget {
  const _InlineChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _toPlainText(String raw) {
  var value = raw.trim();
  if (value.isEmpty) {
    return value;
  }

  value = value
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  value = value
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  return value;
}

String _formatVnd(int amount) {
  final format = NumberFormat.decimalPattern('vi_VN');
  return '${format.format(amount)}₫';
}

class _EmptyLearningState extends StatelessWidget {
  const _EmptyLearningState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: CourseDetailPalette.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
