import 'package:dio/dio.dart';
import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_constants.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/services/auth_repository.dart';
import 'dart:convert';
import 'dart:typed_data';

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
        final playback = await _fetchLecturePlayback(item.id);
        if (playback != null) {
          return playback;
        }

        final candidates = <String?>[
          item.mediaUrl,
          item.mediaHlsUrl,
          item.mediaStreamingUrl,
        ];
        final endpoint = candidates
            .map((value) => value?.trim())
            .firstWhere(
              (value) => value != null && value.isNotEmpty,
              orElse: () => null,
            );
        if (endpoint != null && endpoint.isNotEmpty) {
          return CourseDetailResolvedContent(
            uri: _toAbsoluteUri(endpoint),
            kind: 'video',
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      if (item.isPdfLike) {
        final streamPdfUri = await _resolveStreamPdfUrlByLecture(item.id);
        if (streamPdfUri != null) {
          return CourseDetailResolvedContent(
            uri: streamPdfUri,
            kind: 'pdf',
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      if (item.isDocLike) {
        final streamUri = await _resolveStreamUrlByLecture(item.id);
        if (streamUri != null) {
          return CourseDetailResolvedContent(
            uri: streamUri,
            kind: _inferDocumentKind(item: item, uri: streamUri),
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      if (item.isPptLike) {
        final streamUri = await _resolveStreamUrlByLecture(item.id);
        if (streamUri != null) {
          return CourseDetailResolvedContent(
            uri: streamUri,
            kind: _inferDocumentKind(item: item, uri: streamUri),
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      if (item.isImageLike) {
        final streamUri = await _resolveStreamUrlByLecture(item.id);
        if (streamUri != null) {
          return CourseDetailResolvedContent(
            uri: streamUri,
            kind: _inferDocumentKind(item: item, uri: streamUri),
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      final hasDocumentSource =
          (item.mediaDocumentUrl?.trim().isNotEmpty ?? false) ||
          (item.mediaPptxUrl?.trim().isNotEmpty ?? false);
      if (hasDocumentSource) {
        final streamUri = await _resolveStreamUrlByLecture(item.id);
        if (streamUri != null) {
          return CourseDetailResolvedContent(
            uri: streamUri,
            kind: _inferDocumentKind(item: item, uri: streamUri),
            fallbackPageUri: fallbackPageUri,
            subtitleTracks: item.subtitleTracks,
          );
        }
      }

      final endpoint =
          item.mediaDocumentUrl?.trim() ??
          item.mediaPptxUrl?.trim() ??
          item.preferredContentUrl?.trim();
      if (endpoint != null && endpoint.isNotEmpty) {
        final resolved = item.isPdfLike
            ? await _resolvePdfUrl(endpoint)
            : await _resolveDocumentUrl(endpoint);
        return CourseDetailResolvedContent(
          uri: resolved,
          kind: _inferDocumentKind(item: item, uri: resolved),
          fallbackPageUri: fallbackPageUri,
          subtitleTracks: item.subtitleTracks,
        );
      }

      final direct = item.preferredContentUrl?.trim();
      if (direct != null && direct.isNotEmpty) {
        return CourseDetailResolvedContent(
          uri: _toAbsoluteUri(direct),
          kind: item.isVideoLike ? 'video' : 'web',
          fallbackPageUri: fallbackPageUri,
          subtitleTracks: item.subtitleTracks,
        );
      }

      if (fallbackPageUri != null) {
        return CourseDetailResolvedContent(
          uri: fallbackPageUri,
          kind: 'web',
          fallbackPageUri: fallbackPageUri,
          subtitleTracks: item.subtitleTracks,
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

  Future<CourseDetailResolvedContent?> _fetchLecturePlayback(
    String lectureId,
  ) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get<dynamic>(
        '/mobile/lectures/$lectureId/playback',
        options: _requiredAuthorizedOptions(),
      );
      final payload = _responseMap(response);
      final data = payload['data'];
      if (data is! Map) {
        return null;
      }

      final map = data.map((key, value) => MapEntry(key.toString(), value));
      final streamUrl = (map['stream_url'] as String?)?.trim();
      if (streamUrl == null || streamUrl.isEmpty) {
        return null;
      }

      final subtitleTracksRaw = map['subtitle_paths'];
      final subtitleTracks = subtitleTracksRaw is List
          ? subtitleTracksRaw
                .map(CourseDetailSubtitleTrack.fromJson)
                .where((item) => item.path.isNotEmpty)
                .toList()
          : const <CourseDetailSubtitleTrack>[];

      return CourseDetailResolvedContent(
        uri: _toAbsoluteUri(streamUrl),
        kind: 'video',
        subtitleTracks: subtitleTracks,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw AppException(
          _messageFromError(error, '/mobile/lectures/$lectureId/playback'),
          statusCode: error.response?.statusCode,
        );
      }
      return null;
    }
  }

  Future<CourseLectureProgressStatus> fetchLectureProgress({
    required String lectureId,
  }) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      return CourseLectureProgressStatus.empty;
    }

    try {
      final response = await _dio.get<dynamic>(
        '/lectures/$lectureId/status',
        options: _requiredAuthorizedOptions(),
      );
      final payload = _responseMap(response);
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return CourseLectureProgressStatus.fromJson(data);
      }
      if (data is Map) {
        return CourseLectureProgressStatus.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return CourseLectureProgressStatus.empty;
    } on DioException {
      return CourseLectureProgressStatus.empty;
    }
  }

  Future<Map<String, CourseLectureProgressStatus>> fetchBulkLectureProgress({
    required List<String> lectureIds,
  }) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty || lectureIds.isEmpty) {
      return const <String, CourseLectureProgressStatus>{};
    }

    try {
      final response = await _dio.post<dynamic>(
        '/lectures/bulk-progress',
        data: {'lecture_ids': lectureIds},
        options: _requiredAuthorizedOptions(),
      );
      final payload = _responseMap(response);
      final data = payload['data'];
      final progress = data is Map ? data['progress'] : null;
      if (progress is! Map) {
        return const <String, CourseLectureProgressStatus>{};
      }

      final mapped = <String, CourseLectureProgressStatus>{};
      progress.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          mapped[key.toString()] = CourseLectureProgressStatus.fromJson(value);
        } else if (value is Map) {
          mapped[key.toString()] = CourseLectureProgressStatus.fromJson(
            value.map((entryKey, entryValue) {
              return MapEntry(entryKey.toString(), entryValue);
            }),
          );
        }
      });
      return mapped;
    } on DioException {
      return const <String, CourseLectureProgressStatus>{};
    }
  }

  Future<void> updateLectureProgress({
    required String lectureId,
    required int watchedSeconds,
    String type = 'video',
  }) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _dio.put<dynamic>(
        '/lectures/$lectureId/progress',
        data: {'watched_seconds': watchedSeconds, 'type': type},
        options: _requiredAuthorizedOptions(),
      );
    } on DioException {
      return;
    }
  }

  Future<bool> completeLecture({
    required String lectureId,
    required int watchedSeconds,
    String type = 'video',
  }) async {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post<dynamic>(
        '/lectures/$lectureId/complete',
        data: {'watched_seconds': watchedSeconds, 'type': type},
        options: _requiredAuthorizedOptions(),
      );
      final payload = _responseMap(response);
      return payload['success'] == true;
    } on DioException {
      return false;
    }
  }

  Future<String> loadRemoteText(Uri uri) async {
    final response = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );

    final data = response.data;
    if (data == null || data.trim().isEmpty) {
      throw const AppException('Không tải được file phụ đề.');
    }

    return data;
  }

  Future<Uint8List> loadRemoteBytes(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return _loadRemoteBytesInternal(uri, headers: headers, depth: 0);
  }

  Future<Uint8List> _loadRemoteBytesInternal(
    Uri uri, {
    Map<String, String>? headers,
    required int depth,
  }) async {
    if (depth > 2) {
      throw const AppException('Không tải được dữ liệu tài liệu.');
    }

    Response<List<int>> response;
    try {
      response = await _dio.getUri<List<int>>(
        uri,
        options: Options(
          headers: _documentRequestHeaders(headers),
          responseType: ResponseType.bytes,
          validateStatus: (status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );
    } on DioException catch (error) {
      final unsignedHeaders = _unsignedDocumentHeadersForRetry(
        uri: uri,
        headers: headers,
        error: error,
      );
      if (unsignedHeaders != null) {
        return _loadRemoteBytesInternal(
          uri,
          headers: unsignedHeaders,
          depth: depth + 1,
        );
      }

      final storageVariant = _buildStorageVariantUri(uri);
      if (storageVariant != null &&
          storageVariant.toString() != uri.toString()) {
        return _loadRemoteBytesInternal(
          storageVariant,
          headers: headers,
          depth: depth + 1,
        );
      }
      rethrow;
    }

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const AppException('Không tải được dữ liệu tài liệu.');
    }

    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    final isJsonLike =
        contentType.contains('application/json') ||
        contentType.contains('text/json') ||
        contentType.contains('application/problem+json');
    final isHtmlLike =
        contentType.contains('text/html') ||
        contentType.contains('application/xhtml+xml');

    if (isJsonLike) {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isNotEmpty) {
        try {
          final payload = jsonDecode(text);
          final nestedUrl = _extractDirectFileUrl(payload);
          if (nestedUrl != null && nestedUrl.isNotEmpty) {
            final next = _toAbsoluteUri(nestedUrl);
            if (next.toString() != uri.toString()) {
              return _loadRemoteBytesInternal(
                next,
                headers: headers,
                depth: depth + 1,
              );
            }
          }
        } catch (_) {
          // Keep current bytes; parser phía viewer sẽ xử lý tiếp.
        }
      }
    }

    if (isHtmlLike) {
      throw const AppException('Nguồn tài liệu không trả về file PDF hợp lệ.');
    }

    if (_looksLikePdfUri(uri) && !_looksLikePdfBytes(bytes)) {
      throw const AppException('Dữ liệu nhận được không phải file PDF hợp lệ.');
    }

    return Uint8List.fromList(bytes);
  }

  Map<String, String> _documentRequestHeaders(Map<String, String>? headers) {
    return <String, String>{
      'Accept': 'application/pdf, application/octet-stream, */*',
      ...?headers,
    };
  }

  Map<String, String>? _unsignedDocumentHeadersForRetry({
    required Uri uri,
    required Map<String, String>? headers,
    required DioException error,
  }) {
    if (headers == null || headers.isEmpty) {
      return null;
    }

    final hasAuthorization = headers.keys.any(
      (key) => key.toLowerCase() == 'authorization',
    );
    if (!hasAuthorization) {
      return null;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != 400 && statusCode != 401 && statusCode != 403) {
      return null;
    }

    if (!_looksLikeSignedOrStaticDocumentUri(uri)) {
      return null;
    }

    final sanitized = Map<String, String>.from(headers)
      ..removeWhere((key, _) => key.toLowerCase() == 'authorization')
      ..['Accept'] = '*/*';

    return sanitized;
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

  Future<Uri> _resolvePdfUrl(String endpoint) async {
    return _resolveDocumentUrl(endpoint, preferredExtensions: const ['.pdf']);
  }

  bool _looksLikePdfUri(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.pdf') || path.contains('/stream-pdf/');
  }

  bool _looksLikeSignedOrStaticDocumentUri(Uri uri) {
    final path = uri.path.toLowerCase();
    if (uri.queryParameters.isNotEmpty) {
      return true;
    }
    if (path.contains('/storage/') ||
        path.endsWith('.pdf') ||
        path.endsWith('.doc') ||
        path.endsWith('.docx') ||
        path.endsWith('.ppt') ||
        path.endsWith('.pptx')) {
      return true;
    }

    final webBaseUri = Uri.parse(ApiConfig.webBaseUrl);
    return uri.host != webBaseUri.host;
  }

  bool _looksLikePdfBytes(List<int> bytes) {
    if (bytes.length < 4) {
      return false;
    }
    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  Future<Uri> _resolveDocumentUrl(
    String endpoint, {
    List<String> preferredExtensions = const [],
  }) async {
    final source = _toAbsoluteDocumentUri(endpoint);
    final sourcePath = source.path.toLowerCase();
    if (preferredExtensions.any(
      (extension) => sourcePath.endsWith(extension),
    )) {
      return source;
    }

    try {
      final response = await _dio.getUri<dynamic>(
        source,
        options: Options(
          headers: _authorizedOptions().headers,
          followRedirects: false,
          receiveDataWhenStatusError: true,
          validateStatus: (status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );

      final location = response.headers.value('location')?.trim();
      if (location != null && location.isNotEmpty) {
        return _toAbsoluteUri(location);
      }

      final data = response.data;
      final directUrl = _extractDirectFileUrl(data);
      if (directUrl != null && directUrl.isNotEmpty) {
        return _toAbsoluteUri(directUrl);
      }
    } on DioException {
      return source;
    }

    return source;
  }

  Future<Uri?> _resolveStreamPdfUrlByLecture(String lectureId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/media/stream-pdf/$lectureId',
        options: Options(
          headers: _authorizedOptions().headers,
          followRedirects: false,
          receiveDataWhenStatusError: true,
          validateStatus: (status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );

      final location = response.headers.value('location')?.trim();
      if (location != null && location.isNotEmpty) {
        return _toAbsoluteUri(location);
      }

      final directUrl = _extractDirectFileUrl(response.data);
      if (directUrl != null && directUrl.isNotEmpty) {
        return _toAbsoluteUri(directUrl);
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw AppException(
          _messageFromError(error, '/media/stream-pdf/$lectureId'),
          statusCode: error.response?.statusCode,
        );
      }
    }
    return null;
  }

  Future<Uri?> _resolveStreamUrlByLecture(String lectureId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/media/stream/$lectureId',
        options: Options(
          headers: _authorizedOptions().headers,
          followRedirects: false,
          receiveDataWhenStatusError: true,
          validateStatus: (status) {
            if (status == null) {
              return false;
            }
            return status >= 200 && status < 400;
          },
        ),
      );

      final location = response.headers.value('location')?.trim();
      if (location != null && location.isNotEmpty) {
        return _toAbsoluteUri(location);
      }

      final directUrl = _extractDirectFileUrl(response.data);
      if (directUrl != null && directUrl.isNotEmpty) {
        return _toAbsoluteUri(directUrl);
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 403) {
        throw AppException(
          _messageFromError(error, '/media/stream/$lectureId'),
          statusCode: error.response?.statusCode,
        );
      }
    }
    return null;
  }

  String _inferDocumentKind({
    required CourseDetailLearningItem item,
    required Uri uri,
  }) {
    final path = uri.path.toLowerCase();
    if (item.isPdfLike || path.endsWith('.pdf')) {
      return 'pdf';
    }
    if (item.isPptLike || path.endsWith('.ppt') || path.endsWith('.pptx')) {
      return 'ppt';
    }
    if (item.isDocLike || path.endsWith('.doc') || path.endsWith('.docx')) {
      return 'doc';
    }
    if (item.isImageLike ||
        path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.bmp') ||
        path.endsWith('.svg')) {
      return 'image';
    }
    return 'web';
  }

  Uri _toAbsoluteDocumentUri(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return uri;
    }

    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    final lower = normalized.toLowerCase();
    if (lower.startsWith('public/')) {
      final publicPath = normalized.substring('public/'.length);
      return _toAbsoluteUri('storage/$publicPath');
    }
    if (lower.startsWith('storage/')) {
      return _toAbsoluteUri(normalized);
    }
    if (lower.startsWith('edupen/')) {
      return _toAbsoluteUri('storage/$normalized');
    }
    return _toAbsoluteUri(normalized);
  }

  Uri? _buildStorageVariantUri(Uri uri) {
    final lowerPath = uri.path.toLowerCase();
    if (lowerPath.contains('/storage/')) {
      return null;
    }
    final normalizedPath = uri.path.replaceFirst(RegExp(r'^/+'), '');
    if (normalizedPath.isEmpty) {
      return null;
    }
    final likelyStoragePath =
        normalizedPath.toLowerCase().startsWith('edupen/') ||
        normalizedPath.toLowerCase().startsWith('public/') ||
        normalizedPath.toLowerCase().contains('/pdfs/') ||
        normalizedPath.toLowerCase().contains('/docx/') ||
        normalizedPath.toLowerCase().contains('/documents/');
    if (!likelyStoragePath) {
      return null;
    }
    return uri.replace(path: '/storage/$normalizedPath');
  }

  String? _extractDirectFileUrl(dynamic payload) {
    if (payload == null) {
      return null;
    }

    if (payload is String) {
      final text = payload.trim();
      return text.isEmpty ? null : text;
    }

    if (payload is! Map) {
      return null;
    }

    final map = payload.map((key, value) => MapEntry(key.toString(), value));
    const keys = <String>[
      'url',
      'stream_url',
      'file_url',
      'media_url',
      'download_url',
      'signed_url',
      'path',
    ];

    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final nestedCandidates = <dynamic>[
      map['data'],
      map['result'],
      map['payload'],
    ];
    for (final nested in nestedCandidates) {
      final nestedUrl = _extractDirectFileUrl(nested);
      if (nestedUrl != null && nestedUrl.isNotEmpty) {
        return nestedUrl;
      }
    }

    return null;
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
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return uri;
    }

    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    final absolute = '${ApiConfig.webBaseUrl}/$normalized';
    return Uri.parse(Uri.encodeFull(absolute));
  }
}
