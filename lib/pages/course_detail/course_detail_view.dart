import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_constants.dart';
import 'package:edupen/pages/course_detail/course_detail_lecture_view.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/course_detail/course_detail_repository.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CourseDetailView extends StatefulWidget {
  const CourseDetailView({
    super.key,
    required this.course,
    required this.gradient,
    required this.accentColor,
    required this.sourceLabel,
    this.relatedCourses = const [],
  });

  final HomeCourseItem course;
  final List<Color> gradient;
  final Color accentColor;
  final String sourceLabel;
  final List<HomeCourseItem> relatedCourses;

  @override
  State<CourseDetailView> createState() => _CourseDetailViewState();
}

class _CourseDetailViewState extends State<CourseDetailView> {
  late final CourseDetailData _fallbackData;
  late Future<CourseDetailData> _detailFuture;
  bool _isPurchasingByBalance = false;

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
          isLoading: isLoading,
          isPurchasing: _isPurchasingByBalance,
          errorMessage: errorMessage,
          onRetry: _reload,
          onBalancePurchaseTap: () => _purchaseByBalance(data),
          onLearningItemTap: (item) => _openLearningItem(data, item),
        );
      },
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return CourseDetailCopy.genericErrorMessage;
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
          builder: (_) => QuizDetailView(quizId: item.id),
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
    required this.isLoading,
    required this.isPurchasing,
    required this.errorMessage,
    required this.onRetry,
    required this.onBalancePurchaseTap,
    required this.onLearningItemTap,
  });

  final CourseDetailData data;
  final Color accentColor;
  final bool isLoading;
  final bool isPurchasing;
  final String? errorMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onBalancePurchaseTap;
  final Future<void> Function(CourseDetailLearningItem item) onLearningItemTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CourseDetailPalette.background,
      body: SafeArea(
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context).pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor:
                                    CourseDetailPalette.textPrimary,
                              ),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Chi tiết khóa học',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: CourseDetailPalette.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (isLoading ||
                            errorMessage != null ||
                            !data.isFromApi)
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
                            onAction: errorMessage != null ? onRetry : null,
                          ),
                        if (isLoading ||
                            errorMessage != null ||
                            !data.isFromApi)
                          const SizedBox(height: 14),
                        _HeroSection(data: data, accentColor: accentColor),
                        if (data.purchase.canPurchase) ...[
                          const SizedBox(height: 18),
                          _PurchaseCard(
                            purchase: data.purchase,
                            isPurchasing: isPurchasing,
                            onBalanceTap: onBalancePurchaseTap,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Giới thiệu về khóa học',
                          child: _ExpandableOverview(text: data.overview),
                        ),
                        if (data.features.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SectionCard(
                            title: 'Những gì bạn sẽ nhận được',
                            child: Column(
                              children: List.generate(
                                data.features.length,
                                (index) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == data.features.length - 1
                                        ? 0
                                        : 10,
                                  ),
                                  child: _FeatureRow(
                                    item: data.features[index],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Nội dung khóa học',
                          trailing: Text(
                            '${data.totalSections} phần • ${data.totalLectures} bài giảng • ${data.totalQuizzes} đề thi',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: CourseDetailPalette.textSecondary,
                                  fontWeight: FontWeight.w700,
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
                                            index == data.sections.length - 1
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
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
  const _HeroSection({required this.data, required this.accentColor});

  final CourseDetailData data;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final hero = data.hero;
    final backgroundColors = data.isExam
        ? const [Color(0xFF18335F), Color(0xFF0E1D37)]
        : const [Color(0xFF572845), Color(0xFF36192B)];

    final primaryStats = <_HeroInfoItem>[
      _HeroInfoItem(
        icon: Icons.dashboard_customize_rounded,
        label: '${data.totalSections} phần',
      ),
      _HeroInfoItem(
        icon: Icons.play_lesson_rounded,
        label: '${data.totalLectures} bài giảng',
      ),
      if (hero.totalHoursLabel != null && hero.totalHoursLabel!.isNotEmpty)
        _HeroInfoItem(
          icon: Icons.schedule_rounded,
          label: 'Tổng thời lượng ${hero.totalHoursLabel!}',
        ),
    ];
    final secondaryStats = <_HeroInfoItem>[
      if (hero.authorName != null && hero.authorName!.isNotEmpty)
        _HeroInfoItem(
          icon: Icons.person_outline_rounded,
          label: 'Tác giả: ${hero.authorName!}',
        ),
      if (hero.updatedAtLabel != null && hero.updatedAtLabel!.isNotEmpty)
        _HeroInfoItem(
          icon: Icons.update_rounded,
          label: 'Cập nhật ${hero.updatedAtLabel!}',
        ),
      if (hero.languageLabel != null && hero.languageLabel!.isNotEmpty)
        _HeroInfoItem(icon: Icons.language_rounded, label: hero.languageLabel!),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: backgroundColors,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hero.thumbnailUrl != null && hero.thumbnailUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  hero.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hero.category != null && hero.category!.isNotEmpty)
                        _HeroChip(
                          label: hero.category!,
                          backgroundColor: Colors.white.withValues(alpha: 0.94),
                          foregroundColor: CourseDetailPalette.textPrimary,
                        ),
                      if (hero.badgeLabel != null &&
                          hero.badgeLabel!.isNotEmpty &&
                          hero.badgeLabel != hero.category)
                        _HeroChip(
                          label: hero.badgeLabel!,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          foregroundColor: Colors.white,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    hero.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hero.summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.55,
                    ),
                  ),
                  if (primaryStats.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _HeroInfoWrap(items: primaryStats),
                  ],
                  if (secondaryStats.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _HeroInfoWrap(items: secondaryStats),
                  ],
                  if (hero.isPurchased || hero.progress > 0) ...[
                    const SizedBox(height: 18),
                    _ProgressCard(
                      progress: hero.progress,
                      detail:
                          hero.completedLessons != null &&
                              hero.totalLessons != null
                          ? '${hero.completedLessons}/${hero.totalLessons} nội dung hoàn thành'
                          : 'Tiến độ học đang được đồng bộ từ tài khoản của bạn',
                      accentColor: accentColor,
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeroInfoItem {
  const _HeroInfoItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _HeroInfoWrap extends StatelessWidget {
  const _HeroInfoWrap({required this.items});

  final List<_HeroInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: items
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
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
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
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
    required this.isPurchasing,
    required this.onBalanceTap,
  });

  final CourseDetailPurchaseInfo purchase;
  final bool isPurchasing;
  final Future<void> Function() onBalanceTap;

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CourseDetailPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CourseDetailPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mua gói',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CourseDetailPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Thanh toán trực tiếp bằng số dư ví trong app.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: CourseDetailPalette.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (currentPriceLabel != null) ...[
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                Text(
                  currentPriceLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (purchase.hasDiscount && originalPriceLabel != null)
                  Text(
                    originalPriceLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: CourseDetailPalette.textMuted,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Thanh toán một lần',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: CourseDetailPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (purchase.canPurchase) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isPurchasing ? null : () => onBalanceTap(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: isPurchasing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.account_balance_wallet_rounded),
                label: Text(
                  isPurchasing ? 'Đang thanh toán...' : 'Mua gói bằng số dư',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CourseDetailPalette.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CourseDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: CourseDetailPalette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
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
    final text = widget.text.trim();
    final canExpand = text.length > 220 || '\n'.allMatches(text).length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: !_expanded && canExpand ? 5 : null,
          overflow: !_expanded && canExpand ? TextOverflow.ellipsis : null,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: CourseDetailPalette.textPrimary,
            height: 1.58,
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item});

  final CourseDetailFeature item;

  @override
  Widget build(BuildContext context) {
    final toneColor = resolveCourseDetailTone('info');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: toneColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(resolveCourseDetailIcon(item.iconKey), color: toneColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: CourseDetailPalette.textPrimary,
              height: 1.45,
            ),
          ),
        ),
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
    final headerColor = isExam
        ? const Color(0xFFEAF2FF)
        : const Color(0xFFF3EEFF);

    return Container(
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CourseDetailPalette.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('course-section-${section.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: index == 1,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CourseDetailPalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (section.isLocked)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: CourseDetailPalette.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                section.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: CourseDetailPalette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InlineChip(
                    label: '${section.lectureCount} bài học',
                    backgroundColor: Colors.white,
                    foregroundColor: CourseDetailPalette.textPrimary,
                  ),
                  if (section.videoCount > 0)
                    _InlineChip(
                      label: '${section.videoCount} video',
                      backgroundColor: const Color(0xFFF3E8FF),
                      foregroundColor: const Color(0xFF7C3AED),
                    ),
                  if (section.docxCount > 0)
                    _InlineChip(
                      label: '${section.docxCount} tài liệu',
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF2563EB),
                    ),
                  if (section.pdfCount > 0)
                    _InlineChip(
                      label: '${section.pdfCount} PDF',
                      backgroundColor: const Color(0xFFFEF2F2),
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                  if (section.pptCount > 0)
                    _InlineChip(
                      label: '${section.pptCount} PPT',
                      backgroundColor: const Color(0xFFFFF7ED),
                      foregroundColor: const Color(0xFFEA580C),
                    ),
                  if (section.quizCount > 0)
                    _InlineChip(
                      label: '${section.quizCount} đề thi',
                      backgroundColor: const Color(0xFFDBEAFE),
                      foregroundColor: const Color(0xFF1D4ED8),
                    ),
                  if (section.durationLabel != null &&
                      section.durationLabel!.isNotEmpty)
                    _InlineChip(
                      label: section.durationLabel!,
                      backgroundColor: const Color(0xFFFFFBEB),
                      foregroundColor: const Color(0xFFD97706),
                    ),
                ],
              ),
            ],
          ),
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
              ),
              child: section.items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: _EmptyLearningState(
                        message:
                            'Section này chưa có bài học hoặc đề thi để hiển thị.',
                      ),
                    )
                  : Column(
                      children: List.generate(
                        section.items.length,
                        (itemIndex) => _LearningItemRow(
                          item: section.items[itemIndex],
                          onTap: () => onItemTap(section.items[itemIndex]),
                          isLast: itemIndex == section.items.length - 1,
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

class _LearningItemRow extends StatelessWidget {
  const _LearningItemRow({
    required this.item,
    required this.isLast,
    required this.onTap,
  });

  final CourseDetailLearningItem item;
  final bool isLast;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final toneColor = resolveCourseDetailTone(item.toneKey);

    return Opacity(
      opacity: item.isLocked ? 0.68 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: const BorderSide(color: CourseDetailPalette.border),
                bottom: isLast
                    ? BorderSide.none
                    : const BorderSide(color: CourseDetailPalette.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: toneColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    resolveCourseDetailIcon(item.iconKey),
                    color: toneColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: CourseDetailPalette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                          if (item.isLocked)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 18,
                                color: CourseDetailPalette.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InlineChip(
                            label: item.typeLabel,
                            backgroundColor: toneColor.withValues(alpha: 0.12),
                            foregroundColor: toneColor,
                          ),
                          if (item.badgeLabel != null &&
                              item.badgeLabel!.isNotEmpty)
                            _InlineChip(
                              label: item.badgeLabel!,
                              backgroundColor: CourseDetailPalette.textPrimary
                                  .withValues(alpha: 0.08),
                              foregroundColor: CourseDetailPalette.textPrimary,
                            ),
                        ],
                      ),
                      if (item.metaLabel != null &&
                          item.metaLabel!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.metaLabel!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: CourseDetailPalette.textSecondary,
                                height: 1.45,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyLearningState extends StatelessWidget {
  const _EmptyLearningState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: CourseDetailPalette.textSecondary,
        height: 1.45,
      ),
    );
  }
}
