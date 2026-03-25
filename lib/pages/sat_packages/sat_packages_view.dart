import 'package:edly/pages/course_detail/course_detail_view.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/sat_packages/sat_packages_constants.dart';
import 'package:edly/pages/sat_packages/sat_packages_controller.dart';
import 'package:flutter/material.dart';

class SatPackagesView extends StatefulWidget {
  const SatPackagesView({super.key});

  @override
  State<SatPackagesView> createState() => _SatPackagesViewState();
}

class _SatPackagesViewState extends State<SatPackagesView> {
  late final SatPackagesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SatPackagesController();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCourse(HomeCourseItem course, List<HomeCourseItem> related) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailView(
          course: course,
          gradient: const [Color(0xFF1C2454), Color(0xFF5A54F4)],
          accentColor: const Color(0xFF8EE3FF),
          sourceLabel: 'SAT',
          relatedCourses: related,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;
        final isLoading = _controller.isLoading && data == null;
        final errorMessage = _controller.errorMessage;
        final sections = _controller.sections;
        final courses = _controller.visibleCourses;
        final selectedSlug = _controller.selectedSectionSlug;

        return Scaffold(
          backgroundColor: SatPackagesPalette.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'SAT',
              style: TextStyle(
                color: SatPackagesPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : data == null
                  ? _ErrorState(
                      message: errorMessage ?? 'Không tải được danh sách gói SAT.',
                      onRetry: _controller.load,
                    )
                  : RefreshIndicator(
                      onRefresh: _controller.load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: SatPackagesPalette.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: SatPackagesPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.root.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: SatPackagesPalette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (sections.isNotEmpty) ...[
                                  SizedBox(
                                    height: 34,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: sections.length + 1,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 8),
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          final active = selectedSlug == null;
                                          return ChoiceChip(
                                            label: const Text('Tất cả'),
                                            selected: active,
                                            onSelected: (_) =>
                                                _controller.selectSection(null),
                                          );
                                        }
                                        final section = sections[index - 1];
                                        final active =
                                            selectedSlug == section.slug;
                                        return ChoiceChip(
                                          label: Text(section.title),
                                          selected: active,
                                          onSelected: (_) => _controller
                                              .selectSection(section.slug),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SatPackagesPalette.chip,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '${courses.length} gói đang hiển thị',
                                    style: const TextStyle(
                                      color: SatPackagesPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (courses.isEmpty)
                            const _EmptyState()
                          else
                            ...courses.map(
                              (course) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CourseCard(
                                  course: course,
                                  onTap: () => _openCourse(course, courses),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.onTap,
  });

  final HomeCourseItem course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: SatPackagesPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SatPackagesPalette.border),
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
                child: course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const _ImageFallback(),
                      )
                    : const _ImageFallback(),
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
                        color: SatPackagesPalette.textPrimary,
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
                        color: SatPackagesPalette.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: SatPackagesPalette.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Xem chi tiết gói',
                          style: TextStyle(
                            color: SatPackagesPalette.primary,
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF3FD),
      alignment: Alignment.center,
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: SatPackagesPalette.primary,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

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
              style: const TextStyle(color: SatPackagesPalette.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SatPackagesPalette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SatPackagesPalette.border),
      ),
      child: const Text(
        'Hiện chưa có gói SAT nào để hiển thị.',
        style: TextStyle(color: SatPackagesPalette.textSecondary),
      ),
    );
  }
}
