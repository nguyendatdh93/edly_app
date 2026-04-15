import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/teacher/teacher_models.dart';
import 'package:edly/services/auth_repository.dart';

class TeacherRepository {
  TeacherRepository._internal()
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

  static final TeacherRepository instance = TeacherRepository._internal();

  final Dio _dio;

  Future<TeacherDashboardData> fetchDashboard() async {
    final payload = await _get('/mobile/teacher/dashboard');
    return TeacherDashboardData.fromJson(payload);
  }

  Future<TeacherCourseLibraryData> fetchCourseLibrary() async {
    final payload = await _get('/mobile/teacher/course-library');
    return TeacherCourseLibraryData.fromJson(payload);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập lại để tải trang giáo viên.');
    }

    try {
      final response = await _dio.get<dynamic>(
        path,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return data.map((key, value) => MapEntry(key.toString(), value));
      }

      throw const AppException('Dữ liệu trang giáo viên không hợp lệ.');
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
        return 'Không thể tải trang giáo viên.';
    }
  }
}
