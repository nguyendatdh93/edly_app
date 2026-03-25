import 'package:flutter/material.dart';

class CourseDetailPalette {
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2A44);
  static const Color textSecondary = Color(0xFF6C7893);
  static const Color textMuted = Color(0xFF99A1B5);
  static const Color border = Color(0xFFE1E6F0);
  static const Color info = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  const CourseDetailPalette._();
}

class CourseDetailCopy {
  static const String endpointTemplate = '/mobile/course-detail/{slug}_{id}';
  static const String loadingMessage =
      'Đang tải nội dung khóa học từ API mobile.';
  static const String fallbackMessage =
      'Đang tạm dùng dữ liệu từ trang chủ trong lúc chờ section và đề thi trả về.';
  static const String genericErrorMessage =
      'Không thể tải nội dung khóa học.';

  const CourseDetailCopy._();
}

class CourseDetailVisual {
  const CourseDetailVisual({
    required this.gradient,
    required this.accentColor,
  });

  final List<Color> gradient;
  final Color accentColor;
}

const List<CourseDetailVisual> courseDetailVisuals = [
  CourseDetailVisual(
    gradient: [Color(0xFFE8F0FF), Color(0xFFD8E6FF)],
    accentColor: Color(0xFF3F69FF),
  ),
  CourseDetailVisual(
    gradient: [Color(0xFFFFF0EA), Color(0xFFFFE2D3)],
    accentColor: Color(0xFFFF6F3C),
  ),
  CourseDetailVisual(
    gradient: [Color(0xFFE8FBF7), Color(0xFFD1F4EC)],
    accentColor: Color(0xFF17B97C),
  ),
  CourseDetailVisual(
    gradient: [Color(0xFFFFF4D6), Color(0xFFFFE8A8)],
    accentColor: Color(0xFFFFB020),
  ),
];

CourseDetailVisual courseDetailVisualAt(int index) {
  return courseDetailVisuals[index % courseDetailVisuals.length];
}

IconData resolveCourseDetailIcon(String? key) {
  switch ((key ?? '').trim().toLowerCase()) {
    case 'section':
      return Icons.dashboard_customize_rounded;
    case 'progress':
    case 'insights':
      return Icons.insights_rounded;
    case 'lessons':
    case 'lesson':
    case 'curriculum':
      return Icons.play_lesson_rounded;
    case 'exam':
    case 'quiz':
      return Icons.assignment_rounded;
    case 'route':
    case 'path':
      return Icons.alt_route_rounded;
    case 'teacher':
      return Icons.co_present_rounded;
    case 'price':
      return Icons.local_offer_rounded;
    case 'duration':
      return Icons.schedule_rounded;
    case 'video':
      return Icons.ondemand_video_rounded;
    case 'document':
      return Icons.description_rounded;
    case 'slides':
      return Icons.slideshow_rounded;
    case 'level':
      return Icons.stacked_bar_chart_rounded;
    case 'students':
      return Icons.groups_rounded;
    case 'benefit':
    case 'highlight':
      return Icons.workspace_premium_rounded;
    case 'faq':
      return Icons.quiz_rounded;
    case 'mobile':
      return Icons.phone_iphone_rounded;
    case 'access':
      return Icons.all_inclusive_rounded;
    case 'support':
      return Icons.support_agent_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

Color resolveCourseDetailTone(String? key) {
  switch ((key ?? '').trim().toLowerCase()) {
    case 'success':
    case 'green':
      return CourseDetailPalette.success;
    case 'warning':
    case 'orange':
      return CourseDetailPalette.warning;
    case 'danger':
    case 'red':
      return CourseDetailPalette.danger;
    case 'info':
    case 'blue':
    default:
      return CourseDetailPalette.info;
  }
}
