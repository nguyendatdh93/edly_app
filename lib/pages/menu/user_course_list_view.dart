import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/course_detail/course_detail_view.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/home/home_repository.dart';
import 'package:edly/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';

enum UserCourseListMode { purchased, progress }

extension UserCourseListModeText on UserCourseListMode {
  String get title {
    return switch (this) {
      UserCourseListMode.purchased => 'Đã mua',
      UserCourseListMode.progress => 'Tiến độ học tập',
    };
  }

  String get emptyMessage {
    return switch (this) {
      UserCourseListMode.purchased => 'Bạn chưa sở hữu gói học nào.',
      UserCourseListMode.progress => 'Bạn chưa có tiến độ học tập.',
    };
  }
}

class UserCourseListView extends StatefulWidget {
  const UserCourseListView({
    super.key,
    required this.mode,
    this.currentTab = LearningDockTab.purchasedCourses,
  });

  final UserCourseListMode mode;
  final LearningDockTab currentTab;

  @override
  State<UserCourseListView> createState() => _UserCourseListViewState();
}

class _UserCourseListViewState extends State<UserCourseListView> {
  late Future<HomeDashboardData> _future;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _future = HomeRepository.instance.fetchDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = HomeRepository.instance.fetchDashboard();
    setState(() {
      _future = future;
    });
    await future;
  }

  List<HomeCourseItem> _coursesFrom(HomeDashboardData data) {
    final courses = List<HomeCourseItem>.from(data.purchased);

    if (widget.mode == UserCourseListMode.progress) {
      courses.sort((a, b) => (b.progress ?? 0).compareTo(a.progress ?? 0));
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return courses;
    }

    return courses.where((course) {
      final title = course.title.toLowerCase();
      final category = (course.category ?? '').toLowerCase();
      final description = course.shortDescription.toLowerCase();
      return title.contains(query) ||
          category.contains(query) ||
          description.contains(query);
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

  Future<void> _openCourse(HomeCourseItem course, int index) async {
    final courses = _coursesFrom(await _future);
    final visual = _courseVisualAt(index);

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: visual.gradient,
          accentColor: visual.accentColor,
          sourceLabel: widget.mode.title,
          currentDockTab: widget.currentTab,
          relatedCourses: courses,
        ),
      ),
    );

    if (mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hintText = widget.mode == UserCourseListMode.purchased
        ? 'Tìm khóa học đã mua'
        : 'Tìm khóa học đang học';

    return Scaffold(
      backgroundColor: HomePalette.background,
      bottomNavigationBar: LearningDockBar(currentTab: widget.currentTab),
      appBar: AppBar(
        titleSpacing: 20,
        title: _isSearching
            ? Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: HomePalette.textMuted,
                    ),
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: HomePalette.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Text(
                widget.mode.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: HomePalette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _toggleSearch,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: HomePalette.textPrimary,
              ),
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<HomeDashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _CourseListError(
              message: _messageFromError(snapshot.error),
              onRetry: _reload,
            );
          }

          final courses = _coursesFrom(
            snapshot.data ??
                const HomeDashboardData(
                  purchased: [],
                  featured: [],
                  recent: [],
                  categories: [],
                ),
          );

          if (courses.isEmpty) {
            return _CourseListEmpty(
              message: _searchQuery.trim().isNotEmpty
                  ? 'Không tìm thấy khóa học phù hợp.'
                  : widget.mode.emptyMessage,
              showClearAction: _searchQuery.trim().isNotEmpty,
              onClear: _searchQuery.trim().isNotEmpty
                  ? () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    }
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              children: [
                if (_searchQuery.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${courses.length} kết quả cho "${_searchQuery.trim()}"',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ...List.generate(courses.length, (index) {
                  final course = courses[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == courses.length - 1 ? 0 : 12,
                    ),
                    child: _UserCourseTile(
                      course: course,
                      visual: _courseVisualAt(index),
                      showProgress: widget.mode == UserCourseListMode.progress,
                      onTap: () => _openCourse(course, index),
                    ),
                  );
                }),
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

    return 'Không tải được dữ liệu.';
  }
}

class _UserCourseTile extends StatelessWidget {
  const _UserCourseTile({
    required this.course,
    required this.visual,
    required this.showProgress,
    required this.onTap,
  });

  final HomeCourseItem course;
  final _CourseVisual visual;
  final bool showProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = ((course.progress ?? 0).clamp(0, 100)) / 100;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CourseCover(course: course, visual: visual),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.category ?? 'Gói học',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: visual.accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _UserCourseStatusBadge(showProgress: showProgress),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomePalette.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
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
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(course.progress ?? 0).clamp(0, 100)}%',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: HomePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCover extends StatelessWidget {
  const _CourseCover({required this.course, required this.visual});

  final HomeCourseItem course;
  final _CourseVisual visual;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        height: 92,
        child: course.thumbnailUrl == null || course.thumbnailUrl!.isEmpty
            ? _CourseCoverFallback(visual: visual)
            : Image.network(
                course.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _CourseCoverFallback(visual: visual);
                },
              ),
      ),
    );
  }
}

class _CourseCoverFallback extends StatelessWidget {
  const _CourseCoverFallback({required this.visual});

  final _CourseVisual visual;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.gradient,
        ),
      ),
      child: Icon(Icons.menu_book_rounded, color: visual.accentColor, size: 34),
    );
  }
}

class _CourseListEmpty extends StatelessWidget {
  const _CourseListEmpty({
    required this.message,
    this.showClearAction = false,
    this.onClear,
  });

  final String message;
  final bool showClearAction;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showClearAction
                  ? Icons.search_off_rounded
                  : Icons.menu_book_outlined,
              size: 42,
              color: HomePalette.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: HomePalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showClearAction && onClear != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Xóa tìm kiếm'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserCourseStatusBadge extends StatelessWidget {
  const _UserCourseStatusBadge({required this.showProgress});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = showProgress
        ? const Color(0xFFECFDF5)
        : const Color(0xFFEFF6FF);
    final foregroundColor = showProgress
        ? const Color(0xFF15803D)
        : const Color(0xFF1D4ED8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        showProgress ? 'Đang học' : 'Đã mua',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CourseListError extends StatelessWidget {
  const _CourseListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: HomePalette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseVisual {
  const _CourseVisual({required this.gradient, required this.accentColor});

  final List<Color> gradient;
  final Color accentColor;
}

const List<_CourseVisual> _courseVisuals = [
  _CourseVisual(
    gradient: [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    accentColor: Color(0xFF3F69FF),
  ),
  _CourseVisual(
    gradient: [Color(0xFFFFF0EA), Color(0xFFFFE2D3)],
    accentColor: Color(0xFFFF6F3C),
  ),
  _CourseVisual(
    gradient: [Color(0xFFE8FBF7), Color(0xFFD1F4EC)],
    accentColor: Color(0xFF17B97C),
  ),
  _CourseVisual(
    gradient: [Color(0xFFFFF4D6), Color(0xFFFFE8A8)],
    accentColor: Color(0xFFFFB020),
  ),
];

_CourseVisual _courseVisualAt(int index) {
  return _courseVisuals[index % _courseVisuals.length];
}
