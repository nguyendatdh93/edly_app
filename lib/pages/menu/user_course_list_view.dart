import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/course_detail/course_detail_view.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/home/home_repository.dart';
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
  const UserCourseListView({super.key, required this.mode});

  final UserCourseListMode mode;

  @override
  State<UserCourseListView> createState() => _UserCourseListViewState();
}

class _UserCourseListViewState extends State<UserCourseListView> {
  late Future<HomeDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = HomeRepository.instance.fetchDashboard();
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

    return courses;
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
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        title: Text(widget.mode.title),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
            return _CourseListEmpty(message: widget.mode.emptyMessage);
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: courses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = courses[index];
                return _UserCourseTile(
                  course: course,
                  visual: _courseVisualAt(index),
                  showProgress: widget.mode == UserCourseListMode.progress,
                  onTap: () => _openCourse(course, index),
                );
              },
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
                    Text(
                      course.category ?? 'Gói học',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: visual.accentColor,
                        fontWeight: FontWeight.w800,
                      ),
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
  const _CourseListEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomePalette.textSecondary,
            fontWeight: FontWeight.w700,
          ),
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
