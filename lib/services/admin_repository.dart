import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/models/admin_dashboard.dart';
import 'package:edly/models/admin_management.dart';
import 'package:edly/services/auth_repository.dart';

class AdminRepository {
  AdminRepository._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: const {'Accept': 'application/json'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

  static final AdminRepository instance = AdminRepository._internal();

  final Dio _dio;

  Future<AdminDashboardData> fetchDashboard() {
    return _authorizedGet(
      path: '/mobile/admin/dashboard',
      parser: AdminDashboardData.fromJson,
      fallbackMessage: 'Dữ liệu quản trị không hợp lệ.',
    );
  }

  Future<AdminUsersData> fetchUsers({
    int page = 1,
    int perPage = 20,
    String search = '',
    String role = 'all',
  }) {
    return _authorizedGet(
      path: '/mobile/admin/users',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (role.trim().isNotEmpty) 'role': role.trim(),
      },
      parser: AdminUsersData.fromJson,
      fallbackMessage: 'Dữ liệu người dùng không hợp lệ.',
    );
  }

  Future<AdminCoursesData> fetchCourses({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'all',
  }) {
    return _authorizedGet(
      path: '/mobile/admin/courses',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.trim().isNotEmpty) 'status': status.trim(),
      },
      parser: AdminCoursesData.fromJson,
      fallbackMessage: 'Dữ liệu khóa học không hợp lệ.',
    );
  }

  Future<AdminTransactionsData> fetchTransactions({
    int page = 1,
    int perPage = 20,
    String search = '',
    String status = 'all',
  }) {
    return _authorizedGet(
      path: '/mobile/admin/transactions',
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (status.trim().isNotEmpty) 'status': status.trim(),
      },
      parser: AdminTransactionsData.fromJson,
      fallbackMessage: 'Dữ liệu giao dịch không hợp lệ.',
    );
  }

  Future<T> _authorizedGet<T>({
    required String path,
    required T Function(Map<String, dynamic> data) parser,
    required String fallbackMessage,
    Map<String, dynamic>? queryParameters,
  }) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập lại để tải trang quản trị.');
    }

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return parser(data);
      }
      if (data is Map) {
        return parser(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw AppException(fallbackMessage);
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _messageFromError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
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
        return 'Không thể tải dữ liệu quản trị.';
    }
  }
}
