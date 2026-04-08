import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_view.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/home/home_repository.dart';
import 'package:flutter/material.dart';

class CollectionCoursesView extends StatefulWidget {
  const CollectionCoursesView({
    super.key,
    required this.collectionSlug,
    required this.collectionTitle,
  });

  final String collectionSlug;
  final String collectionTitle;

  @override
  State<CollectionCoursesView> createState() => _CollectionCoursesViewState();
}

class _CollectionCoursesViewState extends State<CollectionCoursesView> {
  late Future<HomeCollectionCourseListData> _future;

  @override
  void initState() {
    super.initState();
    _future = HomeRepository.instance.fetchCollectionCourses(
      slug: widget.collectionSlug,
    );
  }

  Future<void> _reload() async {
    final future = HomeRepository.instance.fetchCollectionCourses(
      slug: widget.collectionSlug,
    );
    setState(() {
      _future = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder sẽ render lỗi.
    }
  }

  Future<void> _openCourse(
    HomeCourseItem course,
    List<HomeCourseItem> relatedCourses,
    String sourceLabel,
  ) async {
    final visual = _visualForCollection(sourceLabel);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: visual.gradient,
          accentColor: visual.accent,
          sourceLabel: sourceLabel,
          relatedCourses: relatedCourses,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _reload();
  }

  _CollectionVisual _visualForCollection(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('ielts')) {
      return const _CollectionVisual(
        gradient: [Color(0xFF05635C), Color(0xFF0F8B72)],
        accent: Color(0xFFC9F5E6),
      );
    }
    if (normalized.contains('sat') || RegExp(r'\bact\b').hasMatch(normalized)) {
      return const _CollectionVisual(
        gradient: [Color(0xFF1C2454), Color(0xFF5A54F4)],
        accent: Color(0xFF8EE3FF),
      );
    }
    return const _CollectionVisual(
      gradient: [Color(0xFF2D5BFF), Color(0xFF17B97C)],
      accent: Color(0xFFEAF0FF),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Không thể tải danh sách khóa học của danh mục.';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeCollectionCourseListData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final headerTitle = data?.collection.title.trim().isNotEmpty == true
            ? data!.collection.title
            : widget.collectionTitle;

        return Scaffold(
          backgroundColor: HomePalette.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: Text(
              headerTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomePalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: snapshot.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
              ? _CollectionErrorState(
                  message: _messageFromError(snapshot.error),
                  onRetry: _reload,
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: _CollectionBody(
                    data:
                        data ??
                        HomeCollectionCourseListData(
                          collection: HomeCollectionSummary(
                            id: '',
                            title: widget.collectionTitle,
                            slug: widget.collectionSlug,
                            description: '',
                          ),
                          courses: const [],
                        ),
                    onCourseTap: _openCourse,
                  ),
                ),
        );
      },
    );
  }
}

class _CollectionBody extends StatelessWidget {
  const _CollectionBody({required this.data, required this.onCourseTap});

  final HomeCollectionCourseListData data;
  final Future<void> Function(
    HomeCourseItem course,
    List<HomeCourseItem> relatedCourses,
    String sourceLabel,
  )
  onCourseTap;

  @override
  Widget build(BuildContext context) {
    final title = data.collection.title.trim().isNotEmpty
        ? data.collection.title.trim()
        : 'Danh mục';
    final description = data.collection.description.trim().isNotEmpty
        ? data.collection.description.trim()
        : 'Danh sách khóa học trong danh mục $title.';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HomePalette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HomePalette.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: HomePalette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: HomePalette.chipBlue,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${data.courses.length} khóa học',
                  style: const TextStyle(
                    color: HomePalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (data.courses.isEmpty)
          const _CollectionEmptyState()
        else
          ...data.courses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CollectionCourseCard(
                course: course,
                onTap: () => onCourseTap(course, data.courses, title),
              ),
            ),
          ),
      ],
    );
  }
}

class _CollectionCourseCard extends StatelessWidget {
  const _CollectionCourseCard({required this.course, required this.onTap});

  final HomeCourseItem course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: HomePalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomePalette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
              child: SizedBox(
                width: 124,
                height: 110,
                child:
                    course.thumbnailUrl != null &&
                        course.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _CollectionImageFallback(),
                      )
                    : const _CollectionImageFallback(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                      style: const TextStyle(
                        color: HomePalette.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: HomePalette.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Xem chi tiết khóa học',
                          style: TextStyle(
                            color: HomePalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionImageFallback extends StatelessWidget {
  const _CollectionImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF3FD),
      alignment: Alignment.center,
      child: const Icon(Icons.school_outlined, color: HomePalette.primary),
    );
  }
}

class _CollectionErrorState extends StatelessWidget {
  const _CollectionErrorState({required this.message, required this.onRetry});

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
              style: const TextStyle(color: HomePalette.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomePalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomePalette.border),
      ),
      child: const Text(
        'Hiện chưa có khóa học nào trong danh mục này.',
        style: TextStyle(color: HomePalette.textSecondary),
      ),
    );
  }
}

class _CollectionVisual {
  const _CollectionVisual({required this.gradient, required this.accent});

  final List<Color> gradient;
  final Color accent;
}
