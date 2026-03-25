import 'package:dio/dio.dart';
import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/course_detail/course_detail_constants.dart';
import 'package:edly/pages/course_detail/course_detail_models.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/services/auth_repository.dart';

/// API detail dự kiến cho app mobile:
/// `GET /mobile/course-detail/{slug}_{id}`
///
/// Response nên trả JSON với các nhóm field:
/// - `course`: title, description/content, thumbnail/cover, price, teacher...
/// - `metrics`: list chỉ số hiển thị ở hero/summary
/// - `highlights`: list điểm nổi bật
/// - `curriculum` hoặc `modules`
/// - `faq`
/// - `related_courses`
class CourseDetailRepository {
  CourseDetailRepository._internal()
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

  static final CourseDetailRepository instance =
      CourseDetailRepository._internal();

  final Dio _dio;

  Future<CourseDetailData> fetchCourseDetail({
    required HomeCourseItem course,
    required String sourceLabel,
    List<HomeCourseItem> fallbackRelatedCourses = const [],
  }) async {
    final slug = course.slug;
    final id = course.id;

    final detailPath = '/${slug}_$id';

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/course-detail$detailPath',
        options: _authorizedOptions(),
      );

      return CourseDetailData.fromApiJson(
        _responseMap(response),
        fallbackCourse: course,
        sourceLabel: sourceLabel,
        fallbackRelatedCourses: fallbackRelatedCourses,
      );
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, detailPath),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<BalancePurchaseResult> purchaseCourseByBalance({
    required CourseDetailData detail,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/mobile/purchases/balance',
        data: {
          'content_type': 'course',
          'content_id': detail.coursePublicId.isNotEmpty
              ? detail.coursePublicId
              : detail.courseId,
        },
        options: _requiredAuthorizedOptions(),
      );

      return BalancePurchaseResult.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, '/mobile/purchases/balance'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<CourseDetailResolvedContent> resolveLectureContent({
    required CourseDetailLearningItem item,
    required String courseSlug,
  }) async {
    final fallbackPageUri = _fallbackLecturePageUri(
      courseSlug: courseSlug,
      item: item,
    );

    try {
      if (item.isVideoLike) {
        final endpoint = item.mediaUrl?.trim();
        if (endpoint != null && endpoint.isNotEmpty) {
          final resolved = await _resolveRedirectUrl(endpoint);
          return CourseDetailResolvedContent(
            uri: resolved,
            kind: 'video',
            fallbackPageUri: fallbackPageUri,
          );
        }
      }

      if (item.isPdfLike) {
        final endpoint = item.mediaDocumentUrl?.trim();
        if (endpoint != null && endpoint.isNotEmpty) {
          final resolved = await _resolvePdfUrl(endpoint);
          return CourseDetailResolvedContent(
            uri: resolved,
            kind: 'pdf',
            fallbackPageUri: fallbackPageUri,
          );
        }
      }

      if (item.isPptLike) {
        final direct = item.mediaPptxUrl?.trim();
        if (direct != null && direct.isNotEmpty) {
          return CourseDetailResolvedContent(
            uri: _toAbsoluteUri(direct),
            kind: 'ppt',
            fallbackPageUri: fallbackPageUri,
          );
        }
      }

      final direct = item.preferredContentUrl?.trim();
      if (direct != null && direct.isNotEmpty) {
        return CourseDetailResolvedContent(
          uri: _toAbsoluteUri(direct),
          kind: item.isVideoLike ? 'video' : 'web',
          fallbackPageUri: fallbackPageUri,
        );
      }

      if (fallbackPageUri != null) {
        return CourseDetailResolvedContent(
          uri: fallbackPageUri,
          kind: 'web',
          fallbackPageUri: fallbackPageUri,
        );
      }
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, '/media/stream'),
        statusCode: error.response?.statusCode,
      );
    }

    throw const AppException('Không tìm thấy nguồn nội dung cho bài học này.');
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

  Options _requiredAuthorizedOptions() {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Bạn cần đăng nhập để thực hiện giao dịch.');
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

    throw const AppException('Phản hồi chi tiết gói học không hợp lệ.');
  }

  String _messageFromError(DioException error, String detailPath) {
    final data = error.response?.data;

    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (error.response?.statusCode == 404) {
      if (detailPath == '/mobile/purchases/balance') {
        return 'Backend chưa bật endpoint mua gói trên mobile.';
      }
      return 'Chưa có API chi tiết cho gói học này. Cần thêm endpoint '
          '`GET ${CourseDetailCopy.endpointTemplate.replaceAll('{slug}_{id}', detailPath.replaceFirst('/', ''))}` trên web/backend.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Kết nối tới API chi tiết gói học bị quá thời gian.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối tới API chi tiết gói học.';
      default:
        return CourseDetailCopy.genericErrorMessage;
    }
  }

  Future<Uri> _resolveRedirectUrl(String endpoint) async {
    final response = await _dio.getUri<dynamic>(
      _toAbsoluteUri(endpoint),
      options: Options(
        headers: const {'Accept': 'application/json'},
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) {
          if (status == null) {
            return false;
          }
          return status >= 200 && status < 400;
        },
      ),
    );

    final locationHeader = response.headers.map['location'];
    final location = locationHeader != null && locationHeader.isNotEmpty
        ? locationHeader.first
        : null;

    final resolved = (location ?? response.realUri.toString()).trim();
    if (resolved.isEmpty) {
      throw const AppException('Không đọc được link phát video.');
    }

    return _toAbsoluteUri(resolved);
  }

  Future<Uri> _resolvePdfUrl(String endpoint) async {
    final response = await _dio.getUri<dynamic>(
      _toAbsoluteUri(endpoint),
      options: Options(
        headers: const {'Accept': 'application/json'},
        validateStatus: (status) {
          if (status == null) {
            return false;
          }
          return status >= 200 && status < 400;
        },
      ),
    );

    final payload = _responseMap(response);
    final url = (payload['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw const AppException('Không đọc được link tài liệu PDF.');
    }

    return _toAbsoluteUri(url);
  }

  Uri? _fallbackLecturePageUri({
    required String courseSlug,
    required CourseDetailLearningItem item,
  }) {
    final slug = item.slug?.trim();
    if (slug == null || slug.isEmpty || courseSlug.trim().isEmpty) {
      return null;
    }

    return Uri.tryParse(
      '${ApiConfig.webBaseUrl}/${courseSlug.trim()}/${slug}_${item.id}',
    );
  }

  Uri _toAbsoluteUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      return uri;
    }

    final normalized = raw.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('${ApiConfig.webBaseUrl}/$normalized');
  }
}
