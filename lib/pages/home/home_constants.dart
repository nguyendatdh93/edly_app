import 'package:flutter/material.dart';

class HomePalette {
  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF5A54F4);
  static const Color secondary = Color(0xFF17B97C);
  static const Color textPrimary = Color(0xFF1F2A44);
  static const Color textSecondary = Color(0xFF6C7893);
  static const Color textMuted = Color(0xFF99A1B5);
  static const Color border = Color(0xFFE1E6F0);
  static const Color warning = Color(0xFFFFB020);
  static const Color chipBlue = Color(0xFFEAF0FF);
  static const Color chipGreen = Color(0xFFE6F8F1);

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
