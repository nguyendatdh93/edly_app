import 'package:flutter/material.dart';
import 'package:edly/core/theme/app_colors.dart';

class HomePalette {
  static const Color background = AppColors.surface;
  static const Color surface = AppColors.background;
  static const Color primary = AppColors.primary;
  static const Color secondary = AppColors.primaryDark;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textHint;
  static const Color border = AppColors.border;
  static const Color warning = AppColors.warning;
  static const Color chipBlue = AppColors.primarySoft;
  static const Color chipGreen = AppColors.primarySoft;

  const HomePalette._();
}

class HomeContent {
  static const String appName = 'Edly';
  static const String logoAsset = 'assets/images/edly-logo.png';
  static const String searchHint = 'Tìm kiếm khóa học, bài viết...';

  static const List<HomeDrawerItemData> drawerItems = [
    HomeDrawerItemData('IELTS', Icons.language_rounded),
    HomeDrawerItemData('SAT', Icons.auto_awesome_rounded),
    HomeDrawerItemData('Trang giáo viên', Icons.person_outline_rounded),
    HomeDrawerItemData('Bài viết', Icons.article_outlined),
    HomeDrawerItemData('Hướng dẫn', Icons.info_outline_rounded),
    HomeDrawerItemData('Miễn phí SAT', Icons.menu_book_rounded),
    HomeDrawerItemData('Miễn phí IELTS', Icons.school_outlined),
  ];

  static const List<HomeHeroSlideData> slides = [
    HomeHeroSlideData(
      title: 'Ninja SAT (All-in-one)',
      description:
          'Luyện thi SAT toàn diện với lộ trình gọn, full-length tests, problem sets và video giải chi tiết.',
      buttonText: 'Tiếp tục ôn luyện',
      gradient: [Color(0xFF1C2454), Color(0xFF5A54F4)],
      accent: Color(0xFF8EE3FF),
      highlight: 'Lộ trình Digital SAT nổi bật',
    ),
    HomeHeroSlideData(
      title: 'IELTS 7+ Mastery',
      description:
          'Bộ khóa học tập trung vào Speaking, Writing và chiến lược làm bài để bứt phá band điểm.',
      buttonText: 'Xem chi tiết',
      gradient: [Color(0xFF0F7B6C), Color(0xFF17B97C)],
      accent: Color(0xFFFFE48A),
      highlight: 'Ưu đãi đặc biệt cho học viên mới',
    ),
    HomeHeroSlideData(
      title: 'SAT Practice Tests',
      description:
          'Làm quen phòng thi, kiểm tra tiến độ và tăng tốc với bộ đề SAT mô phỏng sát bài thi thật.',
      buttonText: 'Luyện ngay',
      gradient: [Color(0xFF12263A), Color(0xFF2D5BFF)],
      accent: Color(0xFFFFA86B),
      highlight: 'Phòng thi thử SAT',
    ),
  ];

  const HomeContent._();
}

class HomeDrawerItemData {
  const HomeDrawerItemData(this.title, this.icon);

  final String title;
  final IconData icon;
}

class HomeHeroSlideData {
  const HomeHeroSlideData({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.gradient,
    required this.accent,
    required this.highlight,
  });

  final String title;
  final String description;
  final String buttonText;
  final List<Color> gradient;
  final Color accent;
  final String highlight;
}
