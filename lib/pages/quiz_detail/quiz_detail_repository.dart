import 'package:dio/dio.dart';
import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/services/auth_repository.dart';

class QuizDetailRepository {
  QuizDetailRepository._internal()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

  static final QuizDetailRepository instance = QuizDetailRepository._internal();

  final Dio _dio;

  Future<QuizDetailData> fetchQuizDetail(String quizId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/quizzes/$quizId/detail',
        options: _requiredAuthorizedOptions(),
      );

      return QuizDetailData.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tải thông tin đề thi.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<QuizRoomData> fetchQuizRoom(String quizId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/quizzes/$quizId/room',
        options: _requiredAuthorizedOptions(),
      );

      return QuizRoomData.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể tải dữ liệu phòng thi.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<BalancePurchaseResult> purchaseQuizByBalance({
    required String quizId,
    required String courseId,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/mobile/purchases/balance',
        data: {
          'content_type': 'quiz',
          'content_id': quizId,
          'course_id': courseId,
        },
        options: _requiredAuthorizedOptions(),
      );

      return BalancePurchaseResult.fromJson(_responseMap(response));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Không thể mua quyền vào phòng thi lúc này.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<QuizResultData> submitAndFetchResult({
    required QuizRoomData room,
    required Map<String, String> selectedOptions,
    required Map<String, String> textAnswers,
    Map<String, bool>? markedFlags,
    Map<String, dynamic>? moduleTimes,
    bool isSingleModule = false,
    String? selectedModule,
  }) async {
    final submit = await submitQuiz(
      room: room,
      selectedOptions: selectedOptions,
      textAnswers: textAnswers,
      markedFlags: markedFlags,
      moduleTimes: moduleTimes,
      isSingleModule: isSingleModule,
      selectedModule: selectedModule,
    );
    return fetchResult(submit.uuid);
  }

  Future<QuizSubmitResult> submitQuiz({
    required QuizRoomData room,
    required Map<String, String> selectedOptions,
    required Map<String, String> textAnswers,
    Map<String, bool>? markedFlags,
    Map<String, dynamic>? moduleTimes,
    bool isSingleModule = false,
    String? selectedModule,
  }) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      throw const AppException('Bạn cần đăng nhập lại để nộp bài.');
    }

    final endpoint = room.isExam ? room.examEndpoint : room.exerciseEndpoint;
    if (endpoint.isEmpty) {
      throw const AppException('Thiếu endpoint nộp bài từ backend.');
    }

    final answers = room.questions
        .map(
          (question) => {
            'sort': question.sort,
            'question_id': question.id,
            'option_id': selectedOptions[question.id] ?? '',
            'answer_text': textAnswers[question.id] ?? '',
            'type': question.type.toLowerCase(),
            'module': question.module,
            'marked': markedFlags?[question.id] == true,
          },
        )
        .toList();

    final courseId = room.course?.id;
    if (courseId == null || courseId.isEmpty) {
      throw const AppException('Không xác định được khóa học của đề thi.');
    }

    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: {
          'user_id': user.id,
          'exam_id': room.quiz.id,
          'course_id': courseId,
          'answers': answers,
          'module_times': moduleTimes ?? <String, dynamic>{},
          'source': 'app',
          if (room.isExam) 'is_single_module': isSingleModule,
          if (room.isExam) 'selected_module': selectedModule,
        },
        options: _requiredAuthorizedOptions(),
      );

      final payload = _responseMap(response);
      final redirectUrl = _asNullableString(payload['redirect_url']);
      final uuid = _extractUuidFromRedirect(redirectUrl);

      if (uuid == null || uuid.isEmpty) {
        throw const AppException('Không đọc được mã kết quả sau khi nộp bài.');
      }

      return QuizSubmitResult(uuid: uuid, redirectUrl: redirectUrl ?? '');
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Nộp bài thất bại, vui lòng thử lại.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<QuizResultData> fetchResult(String uuid) async {
    try {
      final resultResponse = await _dio.get<dynamic>(
        '/mobile/quizzes/result/$uuid',
        options: _requiredAuthorizedOptions(),
      );

      return QuizResultData.fromJson(_responseMap(resultResponse));
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Không thể tải kết quả bài thi lúc này.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Options _requiredAuthorizedOptions() {
    final token = AuthRepository.instance.currentToken;
    if (token == null || token.isEmpty) {
      throw const AppException('Phiên đăng nhập không còn hợp lệ.');
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

    throw const AppException('Phản hồi máy chủ không hợp lệ.');
  }

  String _messageFromError(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }

      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final firstValue = errors.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }
        return firstValue.toString();
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
        return fallback;
    }
  }

  String? _asNullableString(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _extractUuidFromRedirect(String? redirectUrl) {
    if (redirectUrl == null || redirectUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(redirectUrl);
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }

    return uri.pathSegments.last;
  }
}
