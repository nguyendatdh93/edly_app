import 'package:flutter/material.dart';
import 'package:edly/core/theme/app_colors.dart';

/// Chứa bảng màu dùng chung cho màn đăng ký.
class SignUpPalette {
  static const Color background = AppColors.background;
  static const Color primary = AppColors.primary;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color border = AppColors.border;
  static const Color hint = AppColors.textHint;

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
