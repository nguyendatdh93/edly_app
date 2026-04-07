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
        '/mobile/quizzes/$quizId/detail-v6',
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
        '/mobile/quizzes/$quizId/room-v6',
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
    Map<String, Set<String>>? multipleChoiceAnswers,
    Map<String, Map<String, bool>>? yesNoAnswers,
    Map<String, List<String>>? dragDropAnswers,
    Map<String, bool>? markedFlags,
    Map<String, dynamic>? moduleTimes,
    bool isSingleModule = false,
    String? selectedModule,
    int? usedSeconds,
    List<String>? questionIdsOverride,
  }) async {
    final submit = await submitQuiz(
      room: room,
      selectedOptions: selectedOptions,
      textAnswers: textAnswers,
      multipleChoiceAnswers: multipleChoiceAnswers,
      yesNoAnswers: yesNoAnswers,
      dragDropAnswers: dragDropAnswers,
      markedFlags: markedFlags,
      moduleTimes: moduleTimes,
      isSingleModule: isSingleModule,
      selectedModule: selectedModule,
      usedSeconds: usedSeconds,
      questionIdsOverride: questionIdsOverride,
    );
    return fetchResult(
      submit.resultId,
      quizId: room.quiz.id,
      endpointTemplate: room.resultEndpointTemplate.isNotEmpty
          ? room.resultEndpointTemplate
          : submit.resultEndpoint,
    );
  }

  Future<QuizSubmitResult> submitQuiz({
    required QuizRoomData room,
    required Map<String, String> selectedOptions,
    required Map<String, String> textAnswers,
    Map<String, Set<String>>? multipleChoiceAnswers,
    Map<String, Map<String, bool>>? yesNoAnswers,
    Map<String, List<String>>? dragDropAnswers,
    Map<String, bool>? markedFlags,
    Map<String, dynamic>? moduleTimes,
    bool isSingleModule = false,
    String? selectedModule,
    int? usedSeconds,
    List<String>? questionIdsOverride,
  }) async {
    final user = AuthRepository.instance.currentUser;
    if (user == null) {
      throw const AppException('Bạn cần đăng nhập lại để nộp bài.');
    }

    final endpoint = room.submitEndpoint;
    if (endpoint.isEmpty) {
      throw const AppException('Thiếu endpoint nộp bài mới từ backend.');
    }

    final submitPayload = _buildV6SubmitPayload(
      room: room,
      selectedOptions: selectedOptions,
      textAnswers: textAnswers,
      multipleChoiceAnswers: multipleChoiceAnswers ?? const {},
      yesNoAnswers: yesNoAnswers ?? const {},
      dragDropAnswers: dragDropAnswers ?? const {},
      usedSeconds: usedSeconds,
      moduleTimes: moduleTimes,
      questionIdsOverride: questionIdsOverride,
    );

    try {
      final response = await _dio.post<dynamic>(
        endpoint,
        data: submitPayload,
        options: _requiredAuthorizedOptions(),
      );

      final responsePayload = _responseMap(response);
      final result = _asMap(responsePayload['result']);
      final redirectUrl =
          _asNullableString(result['redirect_url']) ??
          _asNullableString(responsePayload['redirect_url']) ??
          '';
      final resultEndpoint =
          _asNullableString(result['result_endpoint']) ?? redirectUrl;
      final resultId =
          _asNullableString(result['id']) ??
          _asNullableString(result['uuid']) ??
          _extractUuidFromRedirect(resultEndpoint) ??
          _extractUuidFromRedirect(redirectUrl);

      if (resultId == null || resultId.isEmpty) {
        throw const AppException('Không đọc được mã kết quả sau khi nộp bài.');
      }

      return QuizSubmitResult(
        resultId: resultId,
        redirectUrl: redirectUrl,
        resultEndpoint: resultEndpoint,
      );
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

  Future<QuizResultData> fetchResult(
    String resultId, {
    String? quizId,
    String? endpointTemplate,
  }) async {
    try {
      final endpoint = (endpointTemplate ?? '').trim().isNotEmpty
          ? _resolveResultEndpointTemplate(endpointTemplate!, resultId)
          : (quizId ?? '').trim().isNotEmpty
          ? '/mobile/quizzes/$quizId/result-v6/$resultId'
          : '';
      if (endpoint.isEmpty) {
        throw const AppException('Thiếu thông tin endpoint để tải kết quả.');
      }

      final resultResponse = await _dio.get<dynamic>(
        endpoint,
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

  Future<String> fetchQuestionNote(String questionId) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/questions/$questionId/note-v6',
        options: _requiredAuthorizedOptions(),
      );

      final payload = _responseMap(response);
      final data = _asMap(payload['data']);
      return _asNullableString(data['content']) ?? '';
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Không thể tải ghi chú cho câu hỏi này.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> saveQuestionNote({
    required String questionId,
    required String content,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/mobile/questions/$questionId/note-v6',
        data: {'content': content},
        options: _requiredAuthorizedOptions(),
      );
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể lưu ghi chú lúc này.'),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchQuestionComments(
    String questionId,
  ) async {
    try {
      final response = await _dio.get<dynamic>(
        '/mobile/questions/$questionId/comments-v6',
        options: _requiredAuthorizedOptions(),
      );

      final payload = _responseMap(response);
      final rows = payload['data'];
      if (rows is! List) {
        return const [];
      }

      return rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(
          error,
          fallback: 'Không thể tải phần thảo luận cho câu hỏi này.',
        ),
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<void> saveQuestionComment({
    required String questionId,
    required String content,
    String? parentId,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/mobile/questions/$questionId/comments-v6',
        data: {
          'content': content,
          if (parentId != null && parentId.trim().isNotEmpty)
            'parent_id': parentId.trim(),
        },
        options: _requiredAuthorizedOptions(),
      );
    } on DioException catch (error) {
      throw AppException(
        _messageFromError(error, fallback: 'Không thể gửi bình luận lúc này.'),
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  Map<String, dynamic> _buildV6SubmitPayload({
    required QuizRoomData room,
    required Map<String, String> selectedOptions,
    required Map<String, String> textAnswers,
    required Map<String, Set<String>> multipleChoiceAnswers,
    required Map<String, Map<String, bool>> yesNoAnswers,
    required Map<String, List<String>> dragDropAnswers,
    required int? usedSeconds,
    Map<String, dynamic>? moduleTimes,
    List<String>? questionIdsOverride,
  }) {
    final questionIds = (questionIdsOverride ?? const <String>[])
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (questionIds.isEmpty) {
      questionIds.addAll(
        room.questionIds.isNotEmpty
            ? room.questionIds
            : room.questions
                  .map((item) => item.id)
                  .where((id) => id.isNotEmpty)
                  .toList(),
      );
    }

    final normalizedOptionOrders = <String, List<String>>{};
    for (final entry in room.optionOrders.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      normalizedOptionOrders[key] = entry.value
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final flatAnswers = room.questions
        .map(
          (question) => _buildV6QuestionAnswer(
            question: question,
            selectedOptions: selectedOptions,
            textAnswers: textAnswers,
            multipleChoiceAnswers: multipleChoiceAnswers,
            yesNoAnswers: yesNoAnswers,
            dragDropAnswers: dragDropAnswers,
          ),
        )
        .whereType<Map<String, dynamic>>()
        .toList();

    final variant = room.variant.toLowerCase();
    final answersPayload = (variant == 'tsa' || variant == 'hsa')
        ? _buildModuleAnswersForTsaHsa(room, flatAnswers)
        : flatAnswers;

    return {
      'answers': answersPayload,
      'question_ids': questionIds,
      'optionOrders': normalizedOptionOrders,
      'option_orders': normalizedOptionOrders,
      'module_times': moduleTimes ?? const {},
      'time': usedSeconds ?? 0,
      'source': 'app',
    };
  }

  List<Map<String, dynamic>> _buildModuleAnswersForTsaHsa(
    QuizRoomData room,
    List<Map<String, dynamic>> flatAnswers,
  ) {
    final answersByQuestion = <String, Map<String, dynamic>>{};
    for (final answer in flatAnswers) {
      final id = _asNullableString(answer['question_id']) ?? '';
      if (id.isNotEmpty) {
        answersByQuestion[id] = answer;
      }
    }

    final modules = _flattenRoomModules(room.modules);
    final payload = <Map<String, dynamic>>[];

    for (final module in modules) {
      final moduleQuestions = module.questions
          .map((item) => answersByQuestion[item.id])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (moduleQuestions.isEmpty) {
        continue;
      }

      payload.add({
        'module_id': module.id,
        'module_name': module.name,
        'questions': moduleQuestions,
      });
    }

    if (payload.isNotEmpty) {
      return payload;
    }

    return [
      {
        'module_id': 'default',
        'module_name': 'Default',
        'questions': flatAnswers,
      },
    ];
  }

  List<QuizRoomModule> _flattenRoomModules(List<QuizRoomModule> modules) {
    final rows = <QuizRoomModule>[];

    void walk(List<QuizRoomModule> items) {
      for (final module in items) {
        rows.add(module);
        if (module.children.isNotEmpty) {
          walk(module.children);
        }
      }
    }

    walk(modules);
    return rows;
  }

  Map<String, dynamic>? _buildV6QuestionAnswer({
    required QuizQuestion question,
    required Map<String, String> selectedOptions,
    required Map<String, String> textAnswers,
    required Map<String, Set<String>> multipleChoiceAnswers,
    required Map<String, Map<String, bool>> yesNoAnswers,
    required Map<String, List<String>> dragDropAnswers,
  }) {
    final type = question.type.toLowerCase().trim();
    final questionId = question.id;
    if (questionId.isEmpty) {
      return null;
    }

    switch (type) {
      case 'single-choice':
        return {
          'question_id': questionId,
          'option_id': selectedOptions[questionId] ?? '',
        };
      case 'multiple-choices':
        final picked = multipleChoiceAnswers[questionId] ?? const <String>{};
        return {
          'question_id': questionId,
          'option_ids': question.options
              .where((option) => option.id.isNotEmpty)
              .map(
                (option) => {
                  'option_id': option.id,
                  'value': picked.contains(option.id),
                },
              )
              .toList(),
        };
      case 'yes-no':
        final values = yesNoAnswers[questionId] ?? const <String, bool>{};
        return {
          'question_id': questionId,
          'option_ids': question.options
              .where((option) => option.id.trim().isNotEmpty)
              .map(
                (option) => {
                  'option_id': option.id,
                  'value': values[option.id] == true,
                },
              )
              .toList(),
        };
      case 'drag-drop':
        final items = dragDropAnswers[questionId] ?? const <String>[];
        return {
          'question_id': questionId,
          'drag_answers': items
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList(),
        };
      case 'essay':
      case 'essay-yes-no':
      case 'short-answer':
      case 'numeric':
      case 'long-answer':
        return {
          'question_id': questionId,
          'content': textAnswers[questionId] ?? '',
        };
      default:
        if (question.options.isNotEmpty) {
          return {
            'question_id': questionId,
            'option_id': selectedOptions[questionId] ?? '',
          };
        }
        return {
          'question_id': questionId,
          'content': textAnswers[questionId] ?? '',
        };
    }
  }

  String _resolveResultEndpointTemplate(String template, String resultId) {
    var endpoint = template.trim();
    if (endpoint.isEmpty) {
      return endpoint;
    }

    endpoint = endpoint.replaceAll('{examId}', resultId);
    endpoint = endpoint.replaceAll('{uuid}', resultId);
    endpoint = endpoint.replaceAll('{id}', resultId);
    return endpoint;
  }
}
