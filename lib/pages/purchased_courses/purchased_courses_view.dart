import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_view.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/home/home_repository.dart';
import 'package:edupen/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';

class PurchasedCoursesView extends StatefulWidget {
  const PurchasedCoursesView({super.key});

  @override
  State<PurchasedCoursesView> createState() => _PurchasedCoursesViewState();
}

class _PurchasedCoursesViewState extends State<PurchasedCoursesView> {
  final TextEditingController _searchController = TextEditingController();
  late Future<HomeDashboardData> _dashboardFuture;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = HomeRepository.instance.fetchDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
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

  Future<void> _openCourse(
    HomeCourseItem course,
    List<HomeCourseItem> relatedCourses,
    int index,
  ) async {
    final visual = _purchasedVisualAt(index);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: visual.gradient,
          accentColor: visual.accentColor,
          sourceLabel: 'Khóa học đã mua',
          relatedCourses: relatedCourses,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reload();
  }

  String _messageFromError(Object? error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Không thể tải danh sách khóa học đã mua.';
  }

  List<HomeCourseItem> _filterPurchased(List<HomeCourseItem> courses) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return courses;
    }

    return courses.where((course) {
      final haystack = [
        course.title,
        course.description,
        course.category ?? '',
        course.slug,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: _isSearching
            ? SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm khóa học đã mua',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomePalette.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: HomePalette.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: HomePalette.primary,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              )
            : const Text(
                'Khóa học đã mua',
                style: TextStyle(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: _toggleSearch,
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                color: HomePalette.textPrimary,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const LearningDockBar(
        currentTab: LearningDockTab.purchasedCourses,
      ),
      body: FutureBuilder<HomeDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _PurchasedErrorState(
              message: _messageFromError(snapshot.error),
              onRetry: _reload,
            );
          }

          final purchased = snapshot.data?.purchased ?? const <HomeCourseItem>[];
          final filteredPurchased = _filterPurchased(purchased);

          return RefreshIndicator(
            onRefresh: _reload,
            child: purchased.isEmpty
                ? const _PurchasedEmptyState()
                : filteredPurchased.isEmpty
                ? _PurchasedEmptyState(
                    message:
                        'Không tìm thấy khóa học phù hợp với "${_searchQuery.trim()}".',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: filteredPurchased.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final course = filteredPurchased[index];
                      final visual = _purchasedVisualAt(index);
                      return _PurchasedCourseCard(
                        course: course,
                        visual: visual,
                        onTap: () =>
                            _openCourse(course, filteredPurchased, index),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _PurchasedCourseCard extends StatelessWidget {
  const _PurchasedCourseCard({
    required this.course,
    required this.visual,
    required this.onTap,
  });

  final HomeCourseItem course;
  final _PurchasedVisual visual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ((course.progress ?? 0).clamp(0, 100)) / 100;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(course: course, visual: visual),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.32,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Tiến độ: ${((course.progress ?? 0).clamp(0, 100))}%',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: HomePalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        if (course.completedLessons != null &&
                            course.totalLessons != null)
                          Text(
                            '${course.completedLessons}/${course.totalLessons}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: HomePalette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: HomePalette.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          visual.accentColor,
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
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.course, required this.visual});

  final HomeCourseItem course;
  final _PurchasedVisual visual;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 104,
        height: 92,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: visual.gradient),
              ),
            ),
            if (course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty)
              Image.network(
                course.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.03),
                    Colors.black.withValues(alpha: 0.32),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: visual.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchasedErrorState extends StatelessWidget {
  const _PurchasedErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: HomePalette.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Tải lại'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchasedEmptyState extends StatelessWidget {
  const _PurchasedEmptyState({
    this.message = 'Bạn chưa có khóa học đã mua để hiển thị.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PurchasedVisual {
  const _PurchasedVisual({required this.gradient, required this.accentColor});

  final List<Color> gradient;
  final Color accentColor;
}

const List<_PurchasedVisual> _purchasedVisuals = [
  _PurchasedVisual(
    gradient: [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    accentColor: Color(0xFF3F69FF),
  ),
  _PurchasedVisual(
    gradient: [Color(0xFFE8FBF7), Color(0xFFD1F4EC)],
    accentColor: Color(0xFF17B97C),
  ),
  _PurchasedVisual(
    gradient: [Color(0xFFFFF0EA), Color(0xFFFFE2D3)],
    accentColor: Color(0xFFFF6F3C),
  ),
];

_PurchasedVisual _purchasedVisualAt(int index) {
  return _purchasedVisuals[index % _purchasedVisuals.length];
}
