import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthPayload {
  const GoogleAuthPayload({
    required this.idToken,
    required this.accessToken,
    required this.sub,
    required this.name,
    required this.email,
    required this.picture,
  });

  final String idToken;
  final String? accessToken;
  final String? sub;
  final String? name;
  final String? email;
  final String? picture;
}

class GoogleAuthService {
  GoogleAuthService._internal()
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: ApiConfig.googleServerClientId.isEmpty
            ? null
            : ApiConfig.googleServerClientId,
      );

  static final GoogleAuthService instance = GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn;

  Future<GoogleAuthPayload?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('GoogleSignIn: user cancelled or no account selected.');
        return null;
      }

      final auth = await account.authentication;
      final idToken = (auth.idToken ?? '').trim();
      if (idToken.isEmpty) {
        throw const AppException(
          'Không thể lấy thông tin xác thực Google. Vui lòng thử lại.',
        );
      }

      return GoogleAuthPayload(
        idToken: idToken,
        accessToken: auth.accessToken?.trim(),
        sub: account.id.trim().isEmpty ? null : account.id.trim(),
        name: account.displayName?.trim(),
        email: account.email.trim().isEmpty ? null : account.email.trim(),
        picture: account.photoUrl?.trim(),
      );
    } on AppException {
      rethrow;
    } on PlatformException catch (error) {
      debugPrint(
        'GoogleSignIn PlatformException '
        'code=${error.code} '
        'message=${error.message} '
        'details=${error.details}',
      );
      throw AppException(_messageFromPlatformException(error));
    } catch (_) {
      throw const AppException(
        'Không thể đăng nhập với Google, vui lòng thử lại.',
      );
    }
  }

  String _messageFromPlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final details = (error.details ?? '').toString().toLowerCase();
    final message = (error.message ?? '').toLowerCase();

    if (code.contains('network')) {
      return 'Không thể kết nối tới Google. Vui lòng kiểm tra mạng.';
    }

    if (code.contains('sign_in_failed') || code.contains('api_exception')) {
      if (details.contains('developer_error') ||
          details.contains(' 10') ||
          details.contains('status{statuscode=developer_error') ||
          message.contains('developer_error')) {
        return 'Google OAuth chưa đúng cho app Android (package name hoặc SHA-1).';
      }

      if (details.contains('12501') || message.contains('12501')) {
        return 'Bạn đã hủy đăng nhập Google.';
      }

      if (details.contains('12500') || message.contains('12500')) {
        return 'Google Sign-In chưa được bật hoặc OAuth client chưa đúng.';
      }

      if (kDebugMode) {
        return 'Đăng nhập Google thất bại [$code]: ${error.message ?? error.details ?? 'unknown error'}';
      }

      return 'Đăng nhập Google thất bại. Vui lòng kiểm tra cấu hình OAuth.';
    }

    return 'Không thể đăng nhập với Google, vui lòng thử lại.';
  }
}
