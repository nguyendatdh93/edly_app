import 'package:flutter/material.dart';

/// Chứa bảng màu dùng chung cho màn đăng nhập.
class SignInPalette {
  static const Color background = Colors.white;
  static const Color primary = Color(0xFF5A54F4);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF232635);
  static const Color textSecondary = Color(0xFFA2A6B3);
  static const Color textMuted = Color(0xFF8E95A5);
  static const Color border = Color(0xFFD8DCE7);
  static const Color divider = Color(0xFFD9DCE6);
  static const Color inputFill = Color(0xFFEAF1FF);
  static const Color inputBorder = Color(0xFFD2DBEE);
  static const Color icon = Color(0xFF9AA3B4);

  const SignInPalette._();
}

/// Chứa toàn bộ text và đường dẫn asset của màn đăng nhập.
class SignInContent {
  static const String appName = 'Edly';
  static const String title = 'Đăng nhập';
  static const String subtitle = 'Chào mừng bạn quay trở lại!';
  static const String googleButton = 'Đăng nhập với Google';
  static const String dividerText = 'hoặc';
  static const String emailLabel = 'Email hoặc số điện thoại';
  static const String emailValue = '';
  static const String passwordLabel = 'Mật khẩu';
  static const String passwordValue = '';
  static const String rememberMe = 'Ghi nhớ đăng nhập';
  static const String forgotPassword = 'Quên mật khẩu?';
  static const String primaryButton = 'Đăng nhập';
  static const String footerPrompt = 'Chưa có tài khoản?';
  static const String footerAction = 'Đăng ký ngay';
  static const String logoAsset = 'assets/images/edly-logo.png';

  const SignInContent._();
}
