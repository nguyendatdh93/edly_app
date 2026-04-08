import 'package:dio/dio.dart';
import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/services/auth_repository.dart';

class HomeRepository {
  HomeRepository._internal()
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

  static final HomeRepository instance = HomeRepository._internal();

  final Dio _dio;

  Future<HomeDashboardData> fetchDashboard() async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập lại để tải trang chủ.');
    }

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/home',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return HomeDashboardData.fromJson(data);
      }
      if (data is Map) {
        return HomeDashboardData.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const AppException('Dữ liệu trang chủ không hợp lệ.');
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<HomeCollectionMenuItem>> fetchCollectionMenu() async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập lại để tải danh mục.');
    }

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/collection/list-menu',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final payload = _normalizeMap(response.data);
      final data = payload['data'];
      if (data is List) {
        return HomeCollectionMenuItem.readList(data);
      }

      if (response.data is List) {
        return HomeCollectionMenuItem.readList(response.data);
      }

      throw const AppException('Dữ liệu danh mục không hợp lệ.');
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<HomeCollectionCourseListData> fetchCollectionCourses({
    required String slug,
  }) async {
    final normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      throw const AppException('Slug danh mục không hợp lệ.');
    }

    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập lại để tải danh mục.');
    }

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/collection/$normalizedSlug/courses',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final payload = _normalizeMap(response.data);
      if (payload.isNotEmpty) {
        return HomeCollectionCourseListData.fromJson(payload);
      }

      throw const AppException('Dữ liệu khóa học của danh mục không hợp lệ.');
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
        return 'Không thể tải dữ liệu trang chủ.';
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }
}
