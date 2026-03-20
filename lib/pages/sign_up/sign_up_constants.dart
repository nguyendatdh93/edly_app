import 'package:flutter/material.dart';

/// Chứa bảng màu dùng chung cho màn đăng ký.
class SignUpPalette {
  static const Color background = Colors.white;
  static const Color primary = Color(0xFF5A54F4);
  static const Color textPrimary = Color(0xFF232635);
  static const Color textSecondary = Color(0xFFA2A6B3);
  static const Color border = Color(0xFFD8DCE7);
  static const Color hint = Color(0xFF7E8798);

  const SignUpPalette._();
}

/// Chứa toàn bộ text và đường dẫn asset của màn đăng ký.
class SignUpContent {
  static const String appName = 'Edly';
  static const String title = 'Đăng ký';
  static const String subtitle = 'Tạo tài khoản mới để bắt đầu';
  static const String fullNameLabel = 'Họ và tên';
  static const String fullNameHint = 'Nhập họ và tên';
  static const String phoneLabel = 'Số điện thoại';
  static const String phoneHint = 'VD: 0912345678';
  static const String passwordLabel = 'Mật khẩu';
  static const String passwordHint = 'Từ 6 đến 25 ký tự';
  static const String confirmPasswordLabel = 'Nhập lại mật khẩu';
  static const String confirmPasswordHint = 'Nhập lại mật khẩu';
  static const String primaryButton = 'Đăng ký';
  static const String footerPrompt = 'Đã có tài khoản?';
  static const String footerAction = 'Đăng nhập';
  static const String logoAsset = 'assets/images/edly-logo.png';

  const SignUpContent._();
}
