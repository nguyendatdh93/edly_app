import 'package:flutter/material.dart';
import 'package:edupen/pages/quiz_detail/rooms/hsa_room/time.dart';

class HsaPreviewCard extends StatelessWidget {
  const HsaPreviewCard({
    super.key,
    required this.quizName,
    required this.moduleNames,
    required this.part3Subjects,
    required this.selectedSubjects,
    required this.onToggleSubject,
    required this.onStart,
  });

  final String quizName;
  final List<String> moduleNames;
  final List<String> part3Subjects;
  final Set<String> selectedSubjects;
  final ValueChanged<String> onToggleSubject;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          margin: const EdgeInsets.all(18),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Kiểm tra cấu trúc bài thi trước khi bắt đầu.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                ...List<Widget>.generate(moduleNames.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Module ${index + 1}: ${moduleNames[index]}',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
                if (part3Subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Phần 3 - Chọn tổ hợp môn',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: part3Subjects.map((subject) {
                      final selected = selectedSubjects.contains(subject);
                      return FilterChip(
                        selected: selected,
                        label: Text(subject),
                        onSelected: (_) => onToggleSubject(subject),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mặc định hệ thống sẽ lấy tối đa 50 câu từ các môn bạn chọn.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Tiếp tục vào phần thi'),
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

class HsaIntroCard extends StatelessWidget {
  const HsaIntroCard({
    super.key,
    required this.moduleName,
    required this.minute,
    required this.onStart,
    required this.moduleIndexText,
  });

  final String moduleName;
  final int minute;
  final String moduleIndexText;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(18),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  moduleIndexText,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  moduleName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Thời gian: $minute phút',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Bắt đầu module'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HsaRoomHeader extends StatelessWidget {
  const HsaRoomHeader({
    super.key,
    required this.quizName,
    required this.moduleName,
    required this.timerText,
    required this.answeredText,
  });

  final String quizName;
  final String moduleName;
  final String timerText;
  final String answeredText;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B4DA1),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  moduleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDBEAFE),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HsaRoomTime(value: timerText, compact: true, highlight: true),
          const SizedBox(width: 12),
          Text(
            answeredText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
