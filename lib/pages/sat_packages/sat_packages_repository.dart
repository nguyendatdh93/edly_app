import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/sat_packages/sat_packages_models.dart';
import 'package:edly/services/auth_repository.dart';

class SatPackagesRepository {
  SatPackagesRepository._internal()
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

  static final SatPackagesRepository instance =
      SatPackagesRepository._internal();

  final Dio _dio;

  Future<SatPackagesData> fetchSatPackages() async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Phiên đăng nhập không còn hợp lệ.');
    }

    final slugs = <String>['sat-act', 'sat', 'sat-act-collection'];
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

  Future<SatPackagesData> _fetchSectionsBySlug({
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
        return SatPackagesData.fromJson(data);
      }
      if (data is Map) {
        return SatPackagesData.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }

      throw const AppException('Dữ liệu danh mục SAT không hợp lệ.');
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
        'Không thể tải danh mục SAT/ACT.',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<SatPackagesData> _fetchFromHomeFallback({
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
      HomeCategorySection? satCategory;
      for (final category in dashboard.categories) {
        final slug = category.slug.toLowerCase();
        final title = category.title.toLowerCase();
        if (slug.contains('sat') || title.contains('sat')) {
          satCategory = category;
          break;
        }
      }

      if (satCategory == null) {
        throw const AppException('Không tìm thấy danh mục SAT/ACT.');
      }

      return SatPackagesData(
        root: SatCollectionRoot(
          id: satCategory.id,
          title: satCategory.title,
          slug: satCategory.slug,
        ),
        sections: [
          SatCollectionSection(
            id: satCategory.id,
            title: satCategory.title,
            slug: satCategory.slug,
            courses: satCategory.courses,
          ),
        ],
        allCourses: satCategory.courses,
      );
    } on DioException catch (error) {
      throw AppException(
        'Không thể tải danh mục SAT/ACT.',
        statusCode: error.response?.statusCode,
      );
    }
  }
}
