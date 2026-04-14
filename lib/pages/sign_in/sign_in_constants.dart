import 'package:flutter/material.dart';
import 'package:edly/core/theme/app_colors.dart';

/// Chứa bảng màu dùng chung cho màn đăng nhập.
class SignInPalette {
  static const Color background = AppColors.background;
  static const Color primary = AppColors.primary;
  static const Color card = AppColors.background;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textHint;
  static const Color border = AppColors.border;
  static const Color divider = AppColors.divider;
  static const Color inputFill = AppColors.primarySoft;
  static const Color inputBorder = AppColors.primaryLight;
  static const Color icon = AppColors.textHint;

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
