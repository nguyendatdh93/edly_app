import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/articles/article_models.dart';
import 'package:edly/services/auth_repository.dart';

class ArticleRepository {
  ArticleRepository._internal()
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

  static final ArticleRepository instance = ArticleRepository._internal();

  final Dio _dio;

  Future<ArticleListResponse> fetchArticles({int page = 1}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/articles',
        queryParameters: {'page': page},
        options: _authorizedOptions(),
      );
      return ArticleListResponse.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tải danh sách bài viết.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<ArticleDetailResponse> fetchArticleDetail(String slug) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/articles/$slug',
        options: _authorizedOptions(),
      );
      return ArticleDetailResponse.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tải chi tiết bài viết.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Options _authorizedOptions() {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      return Options();
    }

    return Options(
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
  }

  Map<String, dynamic> _responseMap(Response<dynamic> response) {
    final data = response.data;

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const AppException('Phản hồi bài viết không hợp lệ.');
  }

  String _messageFromError(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (error.response?.statusCode == 404) {
      return 'Backend chưa bật API bài viết cho mobile.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Kết nối tới API bài viết bị quá thời gian.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối tới API bài viết.';
      default:
        return fallback;
    }
  }
}
