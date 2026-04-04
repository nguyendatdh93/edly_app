import 'package:dio/dio.dart';
import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/ielts_packages/ielts_packages_models.dart';
import 'package:edupen/services/auth_repository.dart';

class IeltsPackagesRepository {
  IeltsPackagesRepository._internal()
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

  static final IeltsPackagesRepository instance =
      IeltsPackagesRepository._internal();

  final Dio _dio;

  Future<IeltsPackagesData> fetchIeltsPackages() async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Phiên đăng nhập không còn hợp lệ.');
    }

    final slugs = <String>['ielts', 'ielts-band', 'ielts-course'];
    AppException? latestError;
    for (final slug in slugs) {
      try {
        return await _fetchSectionsBySlug(token: token, slug: slug);
      } on AppException catch (error) {
        latestError = error;
      }
    }

    try {
      return await _fetchFromHomeFallback(token: token);
    } on AppException catch (error) {
      throw latestError ?? error;
    }
  }

  Future<IeltsPackagesData> _fetchSectionsBySlug({
    required String token,
    required String slug,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/collections/$slug/sections',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return IeltsPackagesData.fromJson(data);
      }
      if (data is Map) {
        return IeltsPackagesData.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const AppException('Dữ liệu danh mục IELTS không hợp lệ.');
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is String && message.trim().isNotEmpty) {
          throw AppException(
            message.trim(),
            statusCode: error.response?.statusCode,
          );
        }
      }
      throw AppException(
        'Không thể tải danh mục IELTS.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<IeltsPackagesData> _fetchFromHomeFallback({
    required String token,
  }) async {
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

      Map<String, dynamic> payload;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        payload = data;
      } else if (data is Map) {
        payload = data.map((key, value) => MapEntry(key.toString(), value));
      } else {
        throw const AppException('Dữ liệu trang chủ không hợp lệ.');
      }

      final dashboard = HomeDashboardData.fromJson(payload);
      HomeCategorySection? ieltsCategory;
      for (final category in dashboard.categories) {
        final slug = category.slug.toLowerCase();
        final title = category.title.toLowerCase();
        if (slug.contains('ielts') || title.contains('ielts')) {
          ieltsCategory = category;
          break;
        }
      }

      if (ieltsCategory == null) {
        throw const AppException('Không tìm thấy danh mục IELTS.');
      }

      return IeltsPackagesData(
        root: IeltsCollectionRoot(
          id: ieltsCategory.id,
          title: ieltsCategory.title,
          slug: ieltsCategory.slug,
        ),
        sections: [
          IeltsCollectionSection(
            id: ieltsCategory.id,
            title: ieltsCategory.title,
            slug: ieltsCategory.slug,
            courses: ieltsCategory.courses,
          ),
        ],
        allCourses: ieltsCategory.courses,
      );
    } on DioException catch (error) {
      throw AppException(
        'Không thể tải danh mục IELTS.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
