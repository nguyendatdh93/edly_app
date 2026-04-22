import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_view.dart';
import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/teacher/teacher_models.dart';
import 'package:edupen/pages/teacher/teacher_repository.dart';
import 'package:edupen/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TeacherCourseLibraryView extends StatefulWidget {
  const TeacherCourseLibraryView({super.key});

  @override
  State<TeacherCourseLibraryView> createState() =>
      _TeacherCourseLibraryViewState();
}

class _TeacherCourseLibraryViewState extends State<TeacherCourseLibraryView> {
  late Future<TeacherCourseLibraryData> _future;
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('vi_VN');

  @override
  void initState() {
    super.initState();
    _future = TeacherRepository.instance.fetchCourseLibrary();
  }

  Future<void> _reload() async {
    final future = TeacherRepository.instance.fetchCourseLibrary();
    setState(() {
      _future = future;
    });
    await future;
  }

  void _openCourse(TeacherCourseItem item) {
    final course = HomeCourseItem(
      id: item.id,
      publicId: item.uuid,
      slug: item.slug,
      title: item.title,
      description: item.description,
      thumbnailUrl: item.thumbnailUrl,
      category: 'Kho tài liệu',
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: const [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
          accentColor: HomePalette.primary,
          sourceLabel: 'Kho tài liệu',
          currentDockTab: LearningDockTab.teacher,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      bottomNavigationBar: const LearningDockBar(
        currentTab: LearningDockTab.teacher,
      ),
      appBar: AppBar(
        title: const Text('Kho tài liệu'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: FutureBuilder<TeacherCourseLibraryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _LibraryError(
              message: _messageFromError(snapshot.error),
              onRetry: _reload,
            );
          }

          final items = snapshot.data?.items ?? const <TeacherCourseItem>[];
          if (items.isEmpty) {
            return const Center(child: Text('Chưa có tài liệu để hiển thị.'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return _CourseLibraryTile(
                  item: item,
                  priceText: _priceText(item),
                  onTap: () => _openCourse(item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _priceText(TeacherCourseItem item) {
    if (item.currentPrice <= 0) {
      return 'Miễn phí';
    }
    return '${_currencyFormat.format(item.currentPrice)}đ';
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Không thể tải kho tài liệu.';
  }
}

class _CourseLibraryTile extends StatelessWidget {
  const _CourseLibraryTile({
    required this.item,
    required this.priceText,
    required this.onTap,
  });

  final TeacherCourseItem item;
  final String priceText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: item.thumbnailUrl == null
                      ? const ColoredBox(
                          color: HomePalette.chipBlue,
                          child: Icon(
                            Icons.folder_copy_rounded,
                            color: HomePalette.primary,
                          ),
                        )
                      : Image.network(
                          item.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const ColoredBox(
                              color: HomePalette.chipBlue,
                              child: Icon(
                                Icons.folder_copy_rounded,
                                color: HomePalette.primary,
                              ),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.totalLectures} bài học • ${item.totalQuizzes} đề • ${item.totalDocuments} tài liệu',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: HomePalette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallBadge(priceText),
                        if (item.isPurchased) const _SmallBadge('Đã sở hữu'),
                        if (item.canCreateSample)
                          const _SmallBadge('Có thể tạo bản mẫu'),
                        if (item.canEditSample)
                          const _SmallBadge('Bản mẫu của bạn'),
                      ],
                    ),
                  ],
                ),
              ),
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

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: HomePalette.chipBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: HomePalette.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
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
