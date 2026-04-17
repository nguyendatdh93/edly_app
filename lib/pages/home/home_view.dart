import 'dart:async';

import 'package:edly/pages/course_detail/course_detail_view.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/home/home_repository.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/widgets/learning_dock_bar.dart';
import 'package:edly/widgets/mobile_payment_sheet.dart';
import 'package:flutter/material.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final TextEditingController _searchController = TextEditingController();
  Timer? _slideTimer;
  int _currentSlide = 0;
  String _searchQuery = '';
  late Future<HomeDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = HomeRepository.instance.fetchDashboard();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reloadDashboard() async {
    try {
      await AuthRepository.instance.refreshCurrentUser();
    } catch (_) {
      // Nếu refresh user lỗi thì vẫn thử tải dashboard.
    }
    final future = HomeRepository.instance.fetchDashboard();

    setState(() {
      _dashboardFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder sẽ render trạng thái lỗi.
    }
  }

  void _startAutoSlide() {
    if (HomeContent.slides.length <= 1) {
      return;
    }

    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final nextPage = (_currentSlide + 1) % HomeContent.slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  void _openCourseDetail(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: visual.gradient,
          accentColor: visual.accentColor,
          sourceLabel: sourceLabel,
          currentDockTab: LearningDockTab.home,
          relatedCourses: relatedCourses,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    try {
      await AuthRepository.instance.refreshCurrentUser();
    } catch (_) {
      // Bỏ qua lỗi refresh user, vẫn reload dashboard.
    }
    await _reloadDashboard();
  }

  Future<void> _openDepositSheet() async {
    final result = await showDepositSheet(context);
    if (!mounted || result?.completed != true) {
      return;
    }

    await _reloadDashboard();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result!.message)));
  }

  HomeDashboardData _filterDashboard(HomeDashboardData data) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return data;
    }

    bool matchesCourse(HomeCourseItem course) {
      final haystack = [
        course.title,
        course.description,
        course.category ?? '',
        course.slug,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }

    final filteredCategories = data.categories
        .map((section) {
          final sectionText = [
            section.title,
            section.description,
            section.slug,
          ].join(' ').toLowerCase();

          if (sectionText.contains(query)) {
            return section;
          }

          final filteredCourses = section.courses
              .where(matchesCourse)
              .toList(growable: false);
          if (filteredCourses.isEmpty) {
            return null;
          }

          return HomeCategorySection(
            id: section.id,
            title: section.title,
            slug: section.slug,
            description: section.description,
            viewAllUrl: section.viewAllUrl,
            courses: filteredCourses,
          );
        })
        .whereType<HomeCategorySection>()
        .toList(growable: false);

    return HomeDashboardData(
      purchased: data.purchased.where(matchesCourse).toList(growable: false),
      featured: data.featured.where(matchesCourse).toList(growable: false),
      recent: data.recent.where(matchesCourse).toList(growable: false),
      categories: filteredCategories,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      bottomNavigationBar: const LearningDockBar(
        currentTab: LearningDockTab.home,
      ),
      body: Builder(
        builder: (context) {
          return RefreshIndicator(
            onRefresh: _reloadDashboard,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  titleSpacing: 16,
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      Image.asset(
                        HomeContent.logoAsset,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: _openDepositSheet,
                        style: IconButton.styleFrom(
                          backgroundColor: HomePalette.chipGreen,
                          foregroundColor: HomePalette.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SearchBox(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 256,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: HomeContent.slides.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentSlide = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == HomeContent.slides.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _HeroSlideCard(
                                  data: HomeContent.slides[index],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SlideIndicator(currentSlide: _currentSlide),
                        const SizedBox(height: 16),
                        FutureBuilder<HomeDashboardData>(
                          future: _dashboardFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return _HomeErrorState(
                                message: _messageFromError(snapshot.error),
                                onRetry: _reloadDashboard,
                              );
                            }

                            final dashboard =
                                snapshot.data ??
                                const HomeDashboardData(
                                  purchased: [],
                                  featured: [],
                                  recent: [],
                                  categories: [],
                                );
                            final filteredDashboard = _filterDashboard(
                              dashboard,
                            );

                            if (filteredDashboard.isEmpty) {
                              return _searchQuery.trim().isNotEmpty
                                  ? const _HomeSearchEmptyState()
                                  : const _HomeEmptyState();
                            }

                            return _HomeSections(
                              data: filteredDashboard,
                              onCourseTap: _openCourseDetail,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không thể tải dữ liệu trang chủ.';
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  static const _searchBorder = OutlineInputBorder(
    borderSide: BorderSide.none,
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onTapOutside: _dismissFocus,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: HomePalette.textPrimary),
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: _searchBorder,
          enabledBorder: _searchBorder,
          focusedBorder: _searchBorder,
          disabledBorder: _searchBorder,
          errorBorder: _searchBorder,
          focusedErrorBorder: _searchBorder,
          hintText: 'Tìm kiếm khóa học',
          hintStyle: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 2, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF9CA3AF),
            ),
          ),
          suffixIcon: Padding(
            padding: EdgeInsets.only(left: 10, right: 2),
            child: Icon(
              Icons.mic_none_rounded,
              size: 18,
              color: Color(0xFF9CA3AF),
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32),
          suffixIconConstraints: BoxConstraints(minWidth: 28, minHeight: 28),
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _HomeSections extends StatelessWidget {
  const _HomeSections({required this.data, required this.onCourseTap});

  final HomeDashboardData data;
  final void Function(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  )
  onCourseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.purchased.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.shopping_bag_outlined,
            iconColor: HomePalette.primary,
            title: 'Gói học đã mua',
            subtitle: 'Tiếp tục học các khóa học bạn đã sở hữu',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 286,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.purchased.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index);
                return _PurchasedCourseCard(
                  data: data.purchased[index],
                  visual: visual,
                  onTap: () => onCourseTap(
                    data.purchased[index],
                    visual,
                    'Gói học đã mua',
                    data.purchased,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (data.featured.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.star_rounded,
            iconColor: HomePalette.warning,
            title: 'Gói học nổi bật',
            subtitle: 'Những khóa học đang được quan tâm nhiều trên web',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 274,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.featured.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index);
                return _ShowcaseCourseCard(
                  data: data.featured[index],
                  visual: visual,
                  tag: 'Nổi bật',
                  badge: 'Top khóa học',
                  onTap: () => onCourseTap(
                    data.featured[index],
                    visual,
                    'Gói học nổi bật',
                    data.featured,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (data.recent.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.visibility_outlined,
            iconColor: Color(0xFF5B8CFF),
            title: 'Gói học đã xem',
            subtitle: 'Tiếp tục học từ những khóa học bạn đã xem gần đây',
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 274,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: data.recent.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final visual = _cardVisualAt(index + 1);
                return _ShowcaseCourseCard(
                  data: data.recent[index],
                  visual: visual,
                  tag: 'Đã xem',
                  badge: 'Xem gần đây',
                  onTap: () => onCourseTap(
                    data.recent[index],
                    visual,
                    'Gói học đã xem',
                    data.recent,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
        ],
        ...List.generate(data.categories.length, (index) {
          final isLast = index == data.categories.length - 1;
          final section = data.categories[index];
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: _CategorySection(section: section, onCourseTap: onCourseTap),
          );
        }),
      ],
    );
  }
}

class _HeroSlideCard extends StatelessWidget {
  const _HeroSlideCard({required this.data});

  final HomeHeroSlideData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.gradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x190F172A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              data.highlight,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: data.gradient.last,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        data.buttonText,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: data.accent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlideIndicator extends StatelessWidget {
  const _SlideIndicator({required this.currentSlide});

  final int currentSlide;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        HomeContent.slides.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentSlide == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentSlide == index
                ? HomePalette.primary
                : HomePalette.border,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: HomePalette.textPrimary,
                            fontSize: 20,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomePalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchasedCourseCard extends StatelessWidget {
  const _PurchasedCourseCard({
    required this.data,
    required this.visual,
    required this.onTap,
  });

  final HomeCourseItem data;
  final _CardVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ((data.progress ?? 0).clamp(0, 100)) / 100;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 296,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HomePalette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourseThumbnail(
                imageUrl: data.thumbnailUrl,
                height: 136,
                visual: visual,
                badge: data.category ?? 'Đã mua',
                badgeColor: visual.accentColor,
                footerLabel: data.totalLessons != null
                    ? '${data.totalLessons} học phần'
                    : null,
                footerIcon: Icons.play_circle_fill_rounded,
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.shortDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HomePalette.textSecondary,
                  height: 1.35,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Progress: ${((data.progress ?? 0).clamp(0, 100))}%',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomePalette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (data.completedLessons != null &&
                      data.totalLessons != null)
                    Text(
                      '${data.completedLessons}/${data.totalLessons}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomePalette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: HomePalette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(visual.accentColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseCourseCard extends StatelessWidget {
  const _ShowcaseCourseCard({
    required this.data,
    required this.visual,
    required this.tag,
    required this.badge,
    required this.onTap,
  });

  final HomeCourseItem data;
  final _CardVisual visual;
  final String tag;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 246,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HomePalette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: HomePalette.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CourseThumbnail(
                    imageUrl: data.thumbnailUrl,
                    height: 138,
                    visual: visual,
                    badge: tag,
                    badgeColor: visual.accentColor,
                    footerIcon: Icons.arrow_outward_rounded,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HomePalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.shortDescription,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomePalette.textSecondary,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.section, required this.onCourseTap});

  final HomeCategorySection section;
  final void Function(
    HomeCourseItem course,
    _CardVisual visual,
    String sourceLabel,
    List<HomeCourseItem> relatedCourses,
  )
  onCourseTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.grid_view_rounded,
          iconColor: HomePalette.secondary,
          title: 'Khóa học ${section.title}',
          subtitle: section.subtitle,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 274,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: section.courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final visual = _cardVisualAt(index + 2);
              return _ShowcaseCourseCard(
                data: section.courses[index],
                visual: visual,
                tag: section.title,
                badge: 'Khám phá ngay',
                onTap: () => onCourseTap(
                  section.courses[index],
                  visual,
                  'Khóa học ${section.title}',
                  section.courses,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseThumbnail extends StatelessWidget {
  const _CourseThumbnail({
    required this.imageUrl,
    required this.height,
    required this.visual,
    required this.badge,
    required this.badgeColor,
    this.footerLabel,
    this.footerIcon,
  });

  final String? imageUrl;
  final double height;
  final _CardVisual visual;
  final String badge;
  final Color badgeColor;
  final String? footerLabel;
  final IconData? footerIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: visual.gradient),
              ),
            ),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),

            if (footerLabel != null)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    footerLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _HomeErrorState extends StatelessWidget {
  const _HomeErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 36,
            color: HomePalette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Text(
        'Chưa có dữ liệu gói học để hiển thị trên trang chủ.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: HomePalette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HomeSearchEmptyState extends StatelessWidget {
  const _HomeSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: HomePalette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'Khong tim thay khoa hoc phu hop voi tu khoa da nhap.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardVisual {
  const _CardVisual({required this.gradient, required this.accentColor});

  final List<Color> gradient;
  final Color accentColor;
}

const List<_CardVisual> _cardVisuals = [
  _CardVisual(
    gradient: [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    accentColor: Color(0xFF3F69FF),
  ),
  _CardVisual(
    gradient: [Color(0xFFFFF0EA), Color(0xFFFFE2D3)],
    accentColor: Color(0xFFFF6F3C),
  ),
  _CardVisual(
    gradient: [Color(0xFFE8FBF7), Color(0xFFD1F4EC)],
    accentColor: Color(0xFF17B97C),
  ),
  _CardVisual(
    gradient: [Color(0xFFFFF4D6), Color(0xFFFFE8A8)],
    accentColor: Color(0xFFFFB020),
  ),
];

_CardVisual _cardVisualAt(int index) {
  return _cardVisuals[index % _cardVisuals.length];
}

void _dismissFocus(PointerDownEvent _) {
  FocusManager.instance.primaryFocus?.unfocus();
}
