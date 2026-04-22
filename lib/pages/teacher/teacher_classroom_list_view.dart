import 'package:edupen/pages/home/home_constants.dart';
import 'package:edupen/pages/teacher/teacher_models.dart';
import 'package:flutter/material.dart';

class TeacherClassroomListView extends StatelessWidget {
  const TeacherClassroomListView({super.key, required this.classrooms});

  final List<TeacherClassroomItem> classrooms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        title: const Text('Danh sách lớp'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: classrooms.isEmpty
          ? const Center(child: Text('Bạn chưa tạo lớp học nào.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: classrooms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = classrooms[index];
                return _ClassroomTile(
                  item: item,
                  onTap: () => _showClassroomDetail(context, item),
                );
              },
            ),
    );
  }

  void _showClassroomDetail(BuildContext context, TeacherClassroomItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              _DetailRow(label: 'Số học sinh', value: '${item.studentCount}'),
              _DetailRow(label: 'Năm học', value: item.schoolYear ?? '-'),
              const SizedBox(height: 16),
              const Text(
                'Quản lý học sinh, bài giao và cấu hình lớp cần API mobile riêng để thao tác native.',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClassroomTile extends StatelessWidget {
  const _ClassroomTile({required this.item, required this.onTap});

  final TeacherClassroomItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final schoolYear = item.schoolYear == null ? '' : ' • ${item.schoolYear}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: HomePalette.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.groups_2_rounded, color: HomePalette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${item.studentCount} học sinh$schoolYear'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
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
