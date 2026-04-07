class QuizDetailData {
  const QuizDetailData({
    required this.quiz,
    required this.course,
    required this.access,
    required this.room,
    required this.history,
  });

  final QuizSummary quiz;
  final QuizCourseSummary? course;
  final QuizAccessState access;
  final QuizRoomState room;
  final List<QuizHistoryItem> history;

  factory QuizDetailData.fromJson(Map<String, dynamic> json) {
    final historyRaw = json['history'];

    return QuizDetailData(
      quiz: QuizSummary.fromJson(_asMap(json['quiz'])),
      course: _asMap(json['course']).isEmpty
          ? null
          : QuizCourseSummary.fromJson(_asMap(json['course'])),
      access: QuizAccessState.fromJson(_asMap(json['access'])),
      room: QuizRoomState.fromJson(_asMap(json['room'])),
      history: historyRaw is List
          ? historyRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizHistoryItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class QuizSummary {
  const QuizSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.minute,
    required this.price,
    required this.status,
    required this.questionCount,
    required this.variant,
    required this.updatedAt,
    required this.modules,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final int minute;
  final int price;
  final String status;
  final int questionCount;
  final String variant;
  final DateTime? updatedAt;
  final List<QuizStructureModule> modules;

  bool get isExamMode => minute > 0;

  factory QuizSummary.fromJson(Map<String, dynamic> json) {
    final metadata = _asMap(json['metadata']);
    final modulesRaw = metadata['modules'];

    return QuizSummary(
      id: _asStr(json['id']),
      name: _asStr(json['name']),
      slug: _asStr(json['slug']),
      description: _asStr(json['description']),
      minute: _asInt(json['minute']),
      price: _asInt(json['price']),
      status: _asStr(json['status']),
      questionCount: _asInt(json['question_count']),
      variant: _asStr(json['variant']),
      updatedAt: DateTime.tryParse(_asStr(json['updated_at'])),
      modules: modulesRaw is List
          ? modulesRaw
                .whereType<Map>()
                .map(
                  (item) => QuizStructureModule.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class QuizStructureModule {
  const QuizStructureModule({
    required this.id,
    required this.name,
    required this.minutes,
  });

  final String id;
  final String name;
  final int minutes;

  bool get isReadingWriting {
    final key = name.toLowerCase();
    return key.contains('reading') ||
        key.contains('writing') ||
        key.contains('rw');
  }

  bool get isMath {
    return name.toLowerCase().contains('math');
  }

  int get defaultQuestionCount {
    if (isReadingWriting) return 27;
    if (isMath) return 22;
    return 0;
  }

  factory QuizStructureModule.fromJson(Map<String, dynamic> json) {
    return QuizStructureModule(
      id: _asStr(json['id']),
      name: _asStr(json['name']),
      minutes: _asInt(json['minutes'] ?? json['minute']),
    );
  }
}

class QuizCourseSummary {
  const QuizCourseSummary({
    required this.id,
    required this.publicId,
    required this.slug,
    required this.title,
  });

  final String id;
  final String publicId;
  final String slug;
  final String title;

  factory QuizCourseSummary.fromJson(Map<String, dynamic> json) {
    return QuizCourseSummary(
      id: _asStr(json['id']),
      publicId: _asStr(json['public_id']),
      slug: _asStr(json['slug']),
      title: _asStr(json['title']),
    );
  }
}

class QuizAccessState {
  const QuizAccessState({
    required this.isPurchased,
    required this.canAccess,
    required this.purchasedAccess,
  });

  final bool isPurchased;
  final bool canAccess;
  final QuizPurchasedAccess purchasedAccess;

  factory QuizAccessState.fromJson(Map<String, dynamic> json) {
    return QuizAccessState(
      isPurchased: json['is_purchased'] == true,
      canAccess: json['can_access'] == true,
      purchasedAccess: QuizPurchasedAccess.fromJson(
        _asMap(json['purchased_access']),
      ),
    );
  }
}

class QuizPurchasedAccess {
  const QuizPurchasedAccess({
    required this.hasCourse,
    required this.sectionIds,
    required this.objectIds,
  });

  final bool hasCourse;
  final List<String> sectionIds;
  final List<String> objectIds;

  factory QuizPurchasedAccess.fromJson(Map<String, dynamic> json) {
    return QuizPurchasedAccess(
      hasCourse: json['hasCourse'] == true,
      sectionIds: _asStringList(json['sectionIds']),
      objectIds: _asStringList(json['objectIds']),
    );
  }
}

class QuizRoomState {
  const QuizRoomState({
    required this.mode,
    required this.status,
    required this.isExam,
  });

  final String mode;
  final String status;
  final bool isExam;

  factory QuizRoomState.fromJson(Map<String, dynamic> json) {
    return QuizRoomState(
      mode: _asStr(json['mode']),
      status: _asStr(json['status']),
      isExam: json['is_exam'] == true,
    );
  }
}

class QuizHistoryItem {
  const QuizHistoryItem({
    required this.id,
    required this.uuid,
    required this.type,
    required this.submissionType,
    required this.score,
    this.createdAt,
  });

  final String id;
  final String uuid;
  final String type;
  final String submissionType;
  final QuizScore score;
  final DateTime? createdAt;

  factory QuizHistoryItem.fromJson(Map<String, dynamic> json) {
    return QuizHistoryItem(
      id: _asStr(json['id']),
      uuid: _asStr(json['uuid']),
      type: _asStr(json['type']),
      submissionType: _asStr(json['stype']),
      score: QuizScore.fromJson(_asMap(json['score'])),
      createdAt: DateTime.tryParse(_asStr(json['created_at'])),
    );
  }
}

class QuizScore {
  const QuizScore({
    required this.totalScore,
    required this.correct,
    required this.wrong,
    required this.rwScore,
    required this.mathScore,
    required this.rawModules,
  });

  final int totalScore;
  final int correct;
  final int wrong;
  final int rwScore;
  final int mathScore;
  final Map<String, QuizRawModuleScore> rawModules;

  int get inferredTotalScore {
    if (totalScore > 0) {
      return totalScore;
    }

    var value = 0;
    for (final entry in rawModules.values) {
      value += entry.score;
    }
    return value;
  }

  factory QuizScore.fromJson(Map<String, dynamic> json) {
    final raw = _asMap(json['raw']);
    final rawModules = <String, QuizRawModuleScore>{};

    for (final key in const ['rw1', 'rw2', 'm1', 'm2']) {
      final value = _asMap(raw[key]);
      if (value.isNotEmpty) {
        rawModules[key] = QuizRawModuleScore.fromJson(value);
      }
    }

    return QuizScore(
      totalScore: _asInt(json['total_score'] ?? json['score']),
      correct: _asInt(json['correct']),
      wrong: _asInt(json['wrong']),
      rwScore: _asInt(json['rw_score']),
      mathScore: _asInt(json['math_score']),
      rawModules: rawModules,
    );
  }
}

class QuizRawModuleScore {
  const QuizRawModuleScore({
    required this.correct,
    required this.total,
    required this.score,
  });

  final int correct;
  final int total;
  final int score;

  factory QuizRawModuleScore.fromJson(Map<String, dynamic> json) {
    return QuizRawModuleScore(
      correct: _asInt(json['correct']),
      total: _asInt(json['total']),
      score: _asInt(json['score']),
    );
  }
}

class QuizRoomData {
  const QuizRoomData({
    required this.quiz,
    required this.course,
    required this.variant,
    required this.mode,
    required this.isExam,
    required this.questions,
    required this.modules,
    required this.questionIds,
    required this.optionOrders,
    required this.submitEndpoint,
    required this.examEndpoint,
    required this.exerciseEndpoint,
    required this.resultEndpointTemplate,
  });

  final QuizSummary quiz;
  final QuizCourseSummary? course;
  final String variant;
  final String mode;
  final bool isExam;
  final List<QuizQuestion> questions;
  final List<QuizRoomModule> modules;
  final List<String> questionIds;
  final Map<String, List<String>> optionOrders;
  final String submitEndpoint;
  final String examEndpoint;
  final String exerciseEndpoint;
  final String resultEndpointTemplate;

  factory QuizRoomData.fromJson(Map<String, dynamic> json) {
    final room = _asMap(json['room']);
    final roomSubmission = _asMap(room['submission']);
    final questionRaw = room['questions'];
    final moduleRaw = room['modules'];

    return QuizRoomData(
      quiz: QuizSummary.fromJson(_asMap(json['quiz'])),
      course: _asMap(json['course']).isEmpty
          ? null
          : QuizCourseSummary.fromJson(_asMap(json['course'])),
      variant: _asStr(room['variant']).isNotEmpty
          ? _asStr(room['variant'])
          : _asStr(_asMap(json['quiz'])['variant']),
      mode: _asStr(room['mode']),
      isExam: room['is_exam'] == true,
      questions: questionRaw is List
          ? questionRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizQuestion.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      modules: moduleRaw is List
          ? moduleRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizRoomModule.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      questionIds: _asStringList(room['question_ids']),
      optionOrders: _readOptionOrderMap(room['option_orders']),
      submitEndpoint: _asStr(roomSubmission['submit_endpoint']),
      examEndpoint: _asStr(roomSubmission['exam_endpoint']),
      exerciseEndpoint: _asStr(roomSubmission['exercise_endpoint']),
      resultEndpointTemplate: _asStr(
        roomSubmission['result_endpoint_template'],
      ),
    );
  }
}

class QuizRoomModule {
  const QuizRoomModule({
    required this.id,
    required this.name,
    required this.minute,
    required this.level,
    required this.parentId,
    required this.questions,
    required this.children,
  });

  final String id;
  final String name;
  final int minute;
  final int level;
  final String parentId;
  final List<QuizQuestion> questions;
  final List<QuizRoomModule> children;

  bool get hasQuestionsRecursively {
    if (questions.isNotEmpty) {
      return true;
    }
    for (final child in children) {
      if (child.hasQuestionsRecursively) {
        return true;
      }
    }
    return false;
  }

  List<String> collectQuestionIds() {
    final ids = <String>[
      ...questions.map((item) => item.id).where((id) => id.isNotEmpty),
    ];
    for (final child in children) {
      ids.addAll(child.collectQuestionIds());
    }
    return ids;
  }

  factory QuizRoomModule.fromJson(Map<String, dynamic> json) {
    final questionsRaw = json['questions'];
    final childrenRaw = json['children'];

    return QuizRoomModule(
      id: _asStr(json['id']),
      name: _asStr(json['name']),
      minute: _asInt(json['minute'] ?? json['minutes']),
      level: _asInt(json['level']),
      parentId: _asStr(json['parent_id']),
      questions: questionsRaw is List
          ? questionsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizQuestion.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      children: childrenRaw is List
          ? childrenRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizRoomModule.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.sort,
    required this.title,
    required this.content,
    required this.type,
    required this.module,
    required this.moduleName,
    required this.domain,
    required this.skill,
    required this.explanation,
    required this.audio,
    required this.transcript,
    required this.maths,
    required this.images,
    required this.options,
  });

  final String id;
  final int sort;
  final String title;
  final String content;
  final String type;
  final String module;
  final String moduleName;
  final String domain;
  final String skill;
  final String explanation;
  final String audio;
  final String transcript;
  final List<QuizMathAsset> maths;
  final List<QuizImageAsset> images;
  final List<QuizOption> options;

  bool get isEssayLike => options.isEmpty;
  String get effectiveModuleName => moduleName.isNotEmpty ? moduleName : module;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];

    return QuizQuestion(
      id: _asStr(json['id']),
      sort: _asInt(json['sort']),
      title: _asStr(json['title']),
      content: _asStr(json['content']),
      type: _asStr(json['type']),
      module: _asStr(json['module']),
      moduleName: _asStr(json['module_name']),
      domain: _asStr(json['domain']),
      skill: _asStr(json['skill']),
      explanation: _asStr(json['explanation']),
      audio: _asStr(json['audio']),
      transcript: _asStr(json['transcript']),
      maths: _readMathAssets(json['maths']),
      images: _readImageAssets(json['images']),
      options: optionsRaw is List
          ? optionsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizOption.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class QuizOption {
  const QuizOption({
    required this.id,
    required this.content,
    required this.isCorrect,
    required this.maths,
    required this.images,
  });

  final String id;
  final String content;
  final bool isCorrect;
  final List<QuizMathAsset> maths;
  final List<QuizImageAsset> images;

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      id: _asStr(json['id']),
      content: _asStr(json['content']),
      isCorrect: json['is_correct'] == true,
      maths: _readMathAssets(json['maths']),
      images: _readImageAssets(json['images']),
    );
  }
}

class QuizMathAsset {
  const QuizMathAsset({
    required this.id,
    required this.mathml,
    required this.omml,
    required this.bin,
  });

  final String id;
  final String mathml;
  final String omml;
  final String bin;

  factory QuizMathAsset.fromJson(Map<String, dynamic> json) {
    return QuizMathAsset(
      id: _asStr(json['id']),
      mathml: _asStr(json['mathml']),
      omml: _asStr(json['omml']),
      bin: _asStr(json['bin']),
    );
  }
}

class QuizImageAsset {
  const QuizImageAsset({required this.id, required this.path});

  final String id;
  final String path;

  factory QuizImageAsset.fromJson(Map<String, dynamic> json) {
    return QuizImageAsset(id: _asStr(json['id']), path: _asStr(json['path']));
  }
}

class QuizSubmitResult {
  const QuizSubmitResult({
    required this.resultId,
    required this.redirectUrl,
    required this.resultEndpoint,
  });

  final String resultId;
  final String redirectUrl;
  final String resultEndpoint;

  String get uuid => resultId;
}

class QuizResultData {
  const QuizResultData({
    required this.uuid,
    required this.type,
    required this.submissionType,
    required this.variant,
    required this.score,
    required this.answers,
    required this.questions,
    required this.quizName,
    required this.quizQuestionCount,
    required this.createdAt,
    required this.secondLeft,
    required this.isSingleModule,
    required this.selectedModule,
    required this.moduleTimes,
  });

  final String uuid;
  final String type;
  final String submissionType;
  final String variant;
  final QuizScore score;
  final List<Map<String, dynamic>> answers;
  final List<QuizQuestion> questions;
  final String quizName;
  final int quizQuestionCount;
  final DateTime? createdAt;
  final int secondLeft;
  final bool isSingleModule;
  final String selectedModule;
  final Map<String, int?> moduleTimes;

  factory QuizResultData.fromJson(Map<String, dynamic> json) {
    final result = _asMap(json['result']);
    final quiz = _asMap(json['quiz']);
    final meta = _asMap(json['meta']);
    final answers = result['answers'];
    final questionsRaw = json['questions'];

    return QuizResultData(
      uuid: _asStr(result['uuid']),
      type: _asStr(result['type']),
      submissionType: _asStr(result['stype']),
      variant: _asStr(meta['variant']),
      score: QuizScore.fromJson(_asMap(result['score'])),
      answers: answers is List
          ? answers
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList()
          : const [],
      questions: questionsRaw is List
          ? questionsRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      QuizQuestion.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      quizName: _asStr(quiz['name']),
      quizQuestionCount: _asInt(quiz['question_count']),
      createdAt: DateTime.tryParse(_asStr(result['created_at'])),
      secondLeft: _asInt(result['second_left']),
      isSingleModule: result['is_single_module'] == true,
      selectedModule: _asStr(result['selected_module']),
      moduleTimes: _readNullableIntMap(result['module_times']),
    );
  }
}

String _asStr(dynamic value) => (value ?? '').toString().trim();

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString();
  return int.tryParse(text) ?? num.tryParse(text)?.toInt() ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

List<QuizMathAsset> _readMathAssets(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => QuizMathAsset.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

List<QuizImageAsset> _readImageAssets(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .whereType<Map>()
      .map((item) => QuizImageAsset.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}

Map<String, int?> _readNullableIntMap(dynamic value) {
  if (value is! Map) {
    return const {};
  }

  return value.map((key, item) {
    if (item == null) {
      return MapEntry(key.toString(), null);
    }
    if (item is int) {
      return MapEntry(key.toString(), item);
    }
    if (item is num) {
      return MapEntry(key.toString(), item.toInt());
    }
    return MapEntry(key.toString(), int.tryParse(item.toString()));
  });
}

Map<String, List<String>> _readOptionOrderMap(dynamic value) {
  if (value is! Map) {
    return const {};
  }

  final result = <String, List<String>>{};
  for (final entry in value.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) {
      continue;
    }
    result[key] = _asStringList(entry.value);
  }
  return result;
}
