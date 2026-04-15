import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_view.dart';
import 'package:edly/pages/teacher/teacher_classroom_list_view.dart';
import 'package:edly/pages/teacher/teacher_course_library_view.dart';
import 'package:edly/pages/teacher/teacher_models.dart';
import 'package:edly/pages/teacher/teacher_repository.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:flutter/material.dart';

class TeacherView extends StatefulWidget {
  const TeacherView({super.key});

  @override
  State<TeacherView> createState() => _TeacherViewState();
}

class _TeacherViewState extends State<TeacherView> {
  late Future<TeacherDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = TeacherRepository.instance.fetchDashboard();
  }

  Future<void> _reload() async {
    final future = TeacherRepository.instance.fetchDashboard();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _openClassrooms(List<TeacherClassroomItem> classrooms) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeacherClassroomListView(classrooms: classrooms),
      ),
    );
  }

  Future<void> _openCourseLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TeacherCourseLibraryView()),
    );
  }

  Future<void> _openQuiz(TeacherQuizItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuizDetailView(quizId: item.id)),
    );
  }

  void _showNativeOnlyMessage(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature cần API mobile để thao tác native.')),
    );
  }

  void _showAssignmentDetail(TeacherAssignmentItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Ngày giao', value: item.publishedAtLabel ?? '-'),
            _DetailRow(
              label: 'Đã làm',
              value: '${item.submitted}/${item.assigned}',
            ),
            _DetailRow(
              label: 'Hoàn thành',
              value: '${item.completionPercent}%',
            ),
            const SizedBox(height: 16),
            const Text(
              'Chi tiết bài giao, bài nộp và lịch sử học sinh cần API mobile riêng.',
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncement(TeacherAnnouncementItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            if (item.createdAtLabel != null) ...[
              const SizedBox(height: 8),
              Text(item.createdAtLabel!),
            ],
            if (item.content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(item.content),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      body: SafeArea(
        child: FutureBuilder<TeacherDashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _TeacherErrorState(
                message: _messageFromError(snapshot.error),
                onRetry: _reload,
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  _TeacherHeader(
                    data: data,
                    onOpenClassrooms: () => _openClassrooms(data.classrooms),
                    onRegisterTeacher: () =>
                        _showNativeOnlyMessage('Đăng ký giáo viên'),
                  ),
                  const SizedBox(height: 16),
                  _ActivityCard(activity: data.assignmentActivity),
                  const SizedBox(height: 16),
                  _QuickActionsCard(
                    data: data,
                    onOpenClassrooms: () => _openClassrooms(data.classrooms),
                    onOpenCourseLibrary: _openCourseLibrary,
                    onMissingApi: _showNativeOnlyMessage,
                  ),
                  const SizedBox(height: 16),
                  _AssignmentsCard(
                    assignments: data.recentAssignments,
                    onOpenDetail: _showAssignmentDetail,
                  ),
                  const SizedBox(height: 16),
                  _ClassroomsCard(
                    classrooms: data.classrooms,
                    onOpenClassrooms: () => _openClassrooms(data.classrooms),
                  ),
                  const SizedBox(height: 16),
                  _LatestQuizzesCard(
                    quizzes: data.latestQuizzes,
                    onOpenQuiz: _openQuiz,
                  ),
                  const SizedBox(height: 16),
                  _AnnouncementsCard(
                    announcements: data.announcements,
                    onOpenAnnouncement: _showAnnouncement,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không thể tải trang giáo viên.';
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({
    required this.data,
    required this.onOpenClassrooms,
    required this.onRegisterTeacher,
  });

  final TeacherDashboardData data;
  final VoidCallback onOpenClassrooms;
  final VoidCallback onRegisterTeacher;

  @override
  Widget build(BuildContext context) {
    final user = AuthRepository.instance.currentUser;
    final canUseTeacherTools = data.teacher.isTeacher || data.teacher.isAdmin;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HomePalette.textPrimary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trang giáo viên',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canUseTeacherTools
                ? 'Xin chào ${user?.name ?? 'giáo viên'}, quản lý lớp học và bài giao ngay trên app.'
                : 'Đăng ký giáo viên để tạo lớp, giao bài và theo dõi học sinh.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderButton(
                label: canUseTeacherTools ? 'Danh sách lớp' : 'Đăng ký',
                icon: canUseTeacherTools
                    ? Icons.groups_2_rounded
                    : Icons.person_add_alt_1_rounded,
                onTap: canUseTeacherTools
                    ? onOpenClassrooms
                    : onRegisterTeacher,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HomePalette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final TeacherAssignmentActivity activity;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Hoạt động giao bài',
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Tỉ lệ hoàn thành',
              value: '${activity.completionPercent}%',
              icon: Icons.task_alt_rounded,
              color: HomePalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricTile(
              label: 'HS trung bình',
              value: '${activity.averageAssignedStudents}',
              icon: Icons.school_rounded,
              color: const Color(0xFF17B97C),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.data,
    required this.onOpenClassrooms,
    required this.onOpenCourseLibrary,
    required this.onMissingApi,
  });

  final TeacherDashboardData data;
  final VoidCallback onOpenClassrooms;
  final VoidCallback onOpenCourseLibrary;
  final ValueChanged<String> onMissingApi;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Chức năng giáo viên',
      child: Column(
        children: [
          _ActionTile(
            title: 'Danh sách lớp',
            icon: Icons.groups_2_outlined,
            onTap: onOpenClassrooms,
          ),
          const Divider(height: 1),
          _ActionTile(
            title: 'Kho tài liệu',
            icon: Icons.folder_copy_outlined,
            onTap: onOpenCourseLibrary,
          ),
          const Divider(height: 1),
          _ActionTile(
            title: 'Tạo lớp / giao bài',
            icon: Icons.add_task_outlined,
            onTap: () => onMissingApi('Tạo lớp / giao bài'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentsCard extends StatelessWidget {
  const _AssignmentsCard({
    required this.assignments,
    required this.onOpenDetail,
  });

  final List<TeacherAssignmentItem> assignments;
  final ValueChanged<TeacherAssignmentItem> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Danh sách bài được giao',
      child: assignments.isEmpty
          ? const _EmptyText('Chưa có bài giao nào.')
          : Column(
              children: assignments
                  .take(10)
                  .map((item) {
                    return _ListActionItem(
                      title: item.title,
                      subtitle:
                          '${item.publishedAtLabel ?? '-'} • ${item.submitted}/${item.assigned} đã làm (${item.completionPercent}%)',
                      onTap: () => onOpenDetail(item),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _ClassroomsCard extends StatelessWidget {
  const _ClassroomsCard({
    required this.classrooms,
    required this.onOpenClassrooms,
  });

  final List<TeacherClassroomItem> classrooms;
  final VoidCallback onOpenClassrooms;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Danh sách lớp học',
      child: classrooms.isEmpty
          ? const _EmptyText('Bạn chưa tạo lớp học nào.')
          : Column(
              children: classrooms
                  .take(8)
                  .map((item) {
                    final schoolYear = item.schoolYear == null
                        ? ''
                        : ' • ${item.schoolYear}';
                    return _ListActionItem(
                      title: item.name,
                      subtitle: '${item.studentCount} học sinh$schoolYear',
                      onTap: onOpenClassrooms,
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _LatestQuizzesCard extends StatelessWidget {
  const _LatestQuizzesCard({required this.quizzes, required this.onOpenQuiz});

  final List<TeacherQuizItem> quizzes;
  final ValueChanged<TeacherQuizItem> onOpenQuiz;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Top 10 học liệu mới',
      child: quizzes.isEmpty
          ? const _EmptyText('Thầy cô vẫn chưa tạo học liệu nào.')
          : Column(
              children: quizzes
                  .map((item) {
                    return _ListActionItem(
                      title: item.name,
                      subtitle: item.createdAtLabel ?? 'Chưa có ngày tạo',
                      onTap: () => onOpenQuiz(item),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard({
    required this.announcements,
    required this.onOpenAnnouncement,
  });

  final List<TeacherAnnouncementItem> announcements;
  final ValueChanged<TeacherAnnouncementItem> onOpenAnnouncement;

  @override
  Widget build(BuildContext context) {
    return _TeacherSection(
      title: 'Bảng tin Edly',
      child: announcements.isEmpty
          ? const _EmptyText('Chưa có thông báo nào.')
          : Column(
              children: announcements
                  .take(10)
                  .map((item) {
                    return _ListActionItem(
                      title: item.title,
                      subtitle: item.content.isNotEmpty
                          ? item.content
                          : item.createdAtLabel ?? '',
                      onTap: () => onOpenAnnouncement(item),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _TeacherSection extends StatelessWidget {
  const _TeacherSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: HomePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: HomePalette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: HomePalette.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ListActionItem extends StatelessWidget {
  const _ListActionItem({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomePalette.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
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

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: HomePalette.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _TeacherErrorState extends StatelessWidget {
  const _TeacherErrorState({required this.message, required this.onRetry});

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
