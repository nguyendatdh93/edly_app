import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/models/account_onboarding.dart';
import 'package:edly/models/account_profile.dart';
import 'package:edly/models/auth_session.dart';
import 'package:edly/models/auth_user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Repository gom toàn bộ luồng xác thực cho app mobile.
class AuthRepository {
  AuthRepository._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: const {
              'Accept': 'application/json',
            },
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ),
        _storage = const FlutterSecureStorage();

  static final AuthRepository instance = AuthRepository._internal();
  static const String _sessionKey = 'edly.auth.session';

  final Dio _dio;
  final FlutterSecureStorage _storage;
  AuthSession? _session;

  AuthUser? get currentUser => _session?.user;
  String? get currentToken => _session?.token;
  bool get isSignedIn => _session != null;
  bool get needsFirstTimeOnboarding {
    final role = currentUser?.role?.trim().toLowerCase();
    return role != 'student' && role != 'parent' && role != 'teacher';
  }

  Future<bool> restoreSession() async {
    final rawSession = await _storage.read(key: _sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return false;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map) {
        await _clearSession();
        return false;
      }

      final storedSession = AuthSession.fromStorageJson(
        Map<String, dynamic>.from(decoded),
      );
      final currentUser = await fetchCurrentUser(token: storedSession.token);
      final refreshedSession = storedSession.copyWith(user: currentUser);
      await _persistSession(refreshedSession);
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<AuthSession> signIn({
    required String login,
    required String password,
  }) {
    final normalizedLogin = _normalizeLoginInput(login);

    return _authenticate(
      path: '/mobile/auth/login',
      data: {
        'email': normalizedLogin,
        'password': password,
        'device_name': ApiConfig.deviceName,
      },
    );
  }

  Future<AuthSession> signUp({
    required String name,
    required String phone,
    required String password,
    required String passwordConfirmation,
  }) {
    return _authenticate(
      path: '/mobile/auth/register',
      data: {
        'name': name,
        'phone': phone,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': ApiConfig.deviceName,
      },
    );
  }

  Future<AuthUser> fetchCurrentUser({String? token}) async {
    final activeToken = _requiredToken(token: token);

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/auth/me',
        options: _authorizedOptions(activeToken),
      );
      final payload = _responseMap(response);
      final userData = payload['user'];

      if (userData is! Map) {
        throw const AppException('Phản hồi người dùng không hợp lệ.');
      }

      return AuthUser.fromJson(Map<String, dynamic>.from(userData));
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<void> signOut() async {
    final activeToken = _session?.token;

    try {
      if (activeToken != null && activeToken.isNotEmpty) {
        await _dio.post<dynamic>(
          '/mobile/auth/logout',
          options: _authorizedOptions(activeToken),
        );
      }
    } catch (_) {
      // Luôn xóa session local kể cả khi request logout thất bại.
    } finally {
      await _clearSession();
    }
  }

  Future<AuthSession> _authenticate({
    required String path,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post<dynamic>(path, data: data);
      final session = AuthSession.fromApiJson(_responseMap(response));
      await _persistSession(session);
      return session;
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<AccountProfileScreenData> fetchAccountProfile({
    int? provinceId,
    int? districtId,
  }) async {
    final activeToken = _requiredToken();

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/profile',
        queryParameters: {
          ...?provinceId == null ? null : {'province_id': provinceId},
          ...?districtId == null ? null : {'district_id': districtId},
        },
        options: _authorizedOptions(activeToken),
      );

      final payload = _responseMap(response);
      final data = AccountProfileScreenData.fromJson(payload);
      await _replaceCurrentUser(data.profile.toAuthUser());
      return data;
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<AccountOnboardingData> fetchAccountOnboarding() async {
    final activeToken = _requiredToken();

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/onboarding',
        options: _authorizedOptions(activeToken),
      );

      return AccountOnboardingData.fromJson(_responseMap(response));
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<AccountOnboardingData> updateAccountOnboarding({
    required String phone,
    required bool examInterestSat,
    required bool examInterestIelts,
    required String role,
  }) async {
    final activeToken = _requiredToken();

    try {
      final response = await _dio.put<dynamic>(
        '/mobile/onboarding',
        data: {
          'phone': phone,
          'exam_interest_sat': examInterestSat,
          'exam_interest_ielts': examInterestIelts,
          'role': role,
        },
        options: _authorizedOptions(activeToken),
      );

      final payload = _responseMap(response);
      final data = AccountOnboardingData.fromJson(payload);
      final refreshedUser = await fetchCurrentUser(token: activeToken);
      await _replaceCurrentUser(refreshedUser);
      return data;
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<AccountProfileScreenData> updateAccountProfile({
    required Map<String, dynamic> payload,
  }) async {
    final activeToken = _requiredToken();

    try {
      final response = await _dio.put<dynamic>(
        '/mobile/profile',
        data: payload,
        options: _authorizedOptions(activeToken),
      );

      final data = AccountProfileScreenData.fromJson(_responseMap(response));
      await _replaceCurrentUser(data.profile.toAuthUser());
      return data;
    } catch (error) {
      _throwFormattedError(error);
    }
  }

  Future<void> _persistSession(AuthSession session) async {
    _session = session;
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> _replaceCurrentUser(AuthUser user) async {
    if (_session == null) {
      return;
    }

    await _persistSession(_session!.copyWith(user: user));
  }

  Future<void> _clearSession() async {
    _session = null;
    await _storage.delete(key: _sessionKey);
  }

  Options _authorizedOptions(String token) {
    return Options(
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  Map<String, dynamic> _responseMap(Response<dynamic> response) {
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    throw const AppException('Phản hồi máy chủ không hợp lệ.');
  }

  Never _throwFormattedError(Object error) {
    if (error is AppException) {
      throw error;
    }

    if (error is DioException) {
      final validationException = _validationExceptionFromDioError(error);
      if (validationException != null) {
        throw validationException;
      }

      throw AppException(
        _messageFromDioError(error),
        statusCode: error.response?.statusCode,
      );
    }

    throw const AppException('Có lỗi xảy ra, vui lòng thử lại.');
  }

  String _messageFromDioError(DioException error) {
    final data = _asStringKeyedMap(error.response?.data);

    if (data != null) {
      final fieldErrors = _extractFieldErrors(data);
      if (fieldErrors.isNotEmpty) {
        return fieldErrors.values.first;
      }

      final message = _readMessage(data['message']);
      if (message != null) {
        return message;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Kết nối tới máy chủ bị quá thời gian.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối tới máy chủ.';
      default:
        return 'Không thể xử lý yêu cầu, vui lòng thử lại.';
    }
  }

  ApiValidationException? _validationExceptionFromDioError(
    DioException error,
  ) {
    if (error.response?.statusCode != 422) {
      return null;
    }

    final data = _asStringKeyedMap(error.response?.data);
    if (data == null) {
      return null;
    }

    final fieldErrors = _extractFieldErrors(data);
    if (fieldErrors.isEmpty) {
      return null;
    }

    final message = _readMessage(data['message']);

    return ApiValidationException(
      _isGenericValidationMessage(message) ? fieldErrors.values.first : (message ?? fieldErrors.values.first),
      statusCode: error.response?.statusCode,
      fieldErrors: fieldErrors,
    );
  }

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }

    return null;
  }

  Map<String, String> _extractFieldErrors(Map<String, dynamic> data) {
    final errors = _asStringKeyedMap(data['errors']);
    if (errors == null) {
      return const {};
    }

    final fieldErrors = <String, String>{};

    errors.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        final message = value.first.toString().trim();
        if (message.isNotEmpty) {
          fieldErrors[key] = message;
        }
        return;
      }

      final message = value?.toString().trim();
      if (message != null && message.isNotEmpty) {
        fieldErrors[key] = message;
      }
    });

    return fieldErrors;
  }

  String? _readMessage(dynamic value) {
    if (value is! String) {
      return null;
    }

    final message = value.trim();
    return message.isEmpty ? null : message;
  }

  bool _isGenericValidationMessage(String? message) {
    if (message == null) {
      return true;
    }

    return message == 'The given data was invalid.';
  }

  String _normalizeLoginInput(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains('@')) {
      return trimmed;
    }

    var phone = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('+84')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('84') && phone.length == 11) {
      phone = '0${phone.substring(2)}';
    }

    return phone;
  }

  String _requiredToken({String? token}) {
    final activeToken = token ?? _session?.token;
    if (activeToken == null || activeToken.isEmpty) {
      throw const AppException('Phiên đăng nhập không còn hợp lệ.');
    }

    return activeToken;
  }
}
