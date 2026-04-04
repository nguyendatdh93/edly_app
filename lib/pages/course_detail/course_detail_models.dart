import 'package:edupen/pages/home/home_models.dart';

class CourseDetailData {
  const CourseDetailData({
    required this.hero,
    required this.purchase,
    required this.overview,
    required this.metrics,
    required this.features,
    required this.sections,
    required this.relatedCourses,
    required this.totalSections,
    required this.totalLectures,
    required this.totalQuizzes,
    required this.isFromApi,
    required this.isExam,
    required this.sourceLabel,
    required this.courseId,
    required this.coursePublicId,
    required this.courseSlug,
    required this.isPurchased,
    required this.purchasedAccess,
  });

  final CourseDetailHero hero;
  final CourseDetailPurchaseInfo purchase;
  final String overview;
  final List<CourseDetailMetric> metrics;
  final List<CourseDetailFeature> features;
  final List<CourseDetailSection> sections;
  final List<HomeCourseItem> relatedCourses;
  final int totalSections;
  final int totalLectures;
  final int totalQuizzes;
  final bool isFromApi;
  final bool isExam;
  final String sourceLabel;
  final String courseId;
  final String coursePublicId;
  final String courseSlug;
  final bool isPurchased;
  final CoursePurchasedAccess purchasedAccess;

  factory CourseDetailData.fromApiJson(
    Map<String, dynamic> json, {
    required HomeCourseItem fallbackCourse,
    required String sourceLabel,
    List<HomeCourseItem> fallbackRelatedCourses = const [],
  }) {
    final courseMap = _asMap(json['course']);
    final sectionsRaw = json['sections'];
    final ctaMap = _asMap(json['cta']);
    final rootIsPurchased = json['is_purchased'] == true;
    final purchasedAccess = CoursePurchasedAccess.fromJson(
      _asMap(json['purchased_access']),
    );

    final hero = CourseDetailHero.fromCourseMap(
      courseMap,
      isPurchased: rootIsPurchased,
    );

    final purchase = CourseDetailPurchaseInfo.fromApiJson(
      courseMap,
      ctaMap: ctaMap,
      isPurchased: rootIsPurchased,
    );

    final overview = _asStr(json['overview']).isNotEmpty
        ? _asStr(json['overview'])
        : _asStr(courseMap['overview']);

    final metricsRaw = json['metrics'];
    final metrics = metricsRaw is List
        ? metricsRaw
              .whereType<Map>()
              .map(
                (item) => CourseDetailMetric.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <CourseDetailMetric>[];

    final highlightsRaw = json['highlights'];
    final features = highlightsRaw is List
        ? highlightsRaw
              .whereType<Map>()
              .map(
                (item) => CourseDetailFeature.fromHighlightJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <CourseDetailFeature>[];

    final rawSections = sectionsRaw is List
        ? sectionsRaw
              .whereType<Map>()
              .map(
                (item) => CourseDetailSection.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <CourseDetailSection>[];

    final sections = rawSections
        .map(
          (section) => section.withResolvedAccess(
            isCoursePurchased: rootIsPurchased,
            purchasedAccess: purchasedAccess,
          ),
        )
        .toList();

    final relatedRaw = json['related_courses'];
    final relatedCourses = relatedRaw is List
        ? relatedRaw
              .whereType<Map>()
              .map(
                (item) =>
                    HomeCourseItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : fallbackRelatedCourses;

    final totalSections = _asInt(courseMap['total_sections']);
    final totalLectures = _asInt(courseMap['total_lectures']);
    final totalQuizzes = _asInt(courseMap['total_quizzes']);
    final isExam = json['is_exam'] == true;

    return CourseDetailData(
      hero: hero,
      purchase: purchase,
      overview: overview.isNotEmpty
          ? overview
          : 'Thông tin chi tiết khóa học đang được cập nhật.',
      metrics: metrics,
      features: features,
      sections: sections,
      relatedCourses: relatedCourses,
      totalSections: totalSections > 0 ? totalSections : sections.length,
      totalLectures: totalLectures,
      totalQuizzes: totalQuizzes,
      isFromApi: true,
      isExam: isExam,
      sourceLabel: sourceLabel,
      courseId: _asStr(courseMap['id']).isNotEmpty
          ? _asStr(courseMap['id'])
          : fallbackCourse.id,
      coursePublicId: _asStr(courseMap['public_id']).isNotEmpty
          ? _asStr(courseMap['public_id'])
          : fallbackCourse.publicId,
      courseSlug: _asStr(courseMap['slug']).isNotEmpty
          ? _asStr(courseMap['slug'])
          : fallbackCourse.slug,
      isPurchased: rootIsPurchased,
      purchasedAccess: purchasedAccess,
    );
  }

  factory CourseDetailData.fallback({
    required HomeCourseItem course,
    required String sourceLabel,
    List<HomeCourseItem> fallbackRelatedCourses = const [],
  }) {
    return CourseDetailData(
      hero: CourseDetailHero.fromFallback(course),
      purchase: const CourseDetailPurchaseInfo(),
      overview: course.shortDescription,
      metrics: const [],
      features: const [],
      sections: const [],
      relatedCourses: fallbackRelatedCourses,
      totalSections: 0,
      totalLectures: 0,
      totalQuizzes: 0,
      isFromApi: false,
      isExam: false,
      sourceLabel: sourceLabel,
      courseId: course.id,
      coursePublicId: course.publicId,
      courseSlug: course.slug,
      isPurchased: (course.progress ?? 0) > 0,
      purchasedAccess: const CoursePurchasedAccess.empty(),
    );
  }

  bool canAccessSection(CourseDetailSection section) {
    if (isPurchased) {
      return true;
    }
    if (purchasedAccess.hasCourse) {
      return true;
    }
    return purchasedAccess.sectionIds.contains(section.id);
  }

  bool canAccessItem(CourseDetailLearningItem item) {
    if (isPurchased) {
      return true;
    }
    if (purchasedAccess.hasCourse) {
      return true;
    }
    if (item.price <= 0) {
      return true;
    }
    if (purchasedAccess.sectionIds.contains(item.sectionId)) {
      return true;
    }
    return purchasedAccess.objectIds.contains(item.id);
  }

  CourseDetailLearningItem? get firstAccessibleItem {
    for (final section in sections) {
      for (final item in section.items) {
        if (item.canOpen) {
          return item;
        }
      }
    }
    return null;
  }
}

class CoursePurchasedAccess {
  const CoursePurchasedAccess({
    required this.hasCourse,
    required this.sectionIds,
    required this.objectIds,
  });

  const CoursePurchasedAccess.empty()
    : hasCourse = false,
      sectionIds = const [],
      objectIds = const [];

  final bool hasCourse;
  final List<String> sectionIds;
  final List<String> objectIds;

  factory CoursePurchasedAccess.fromJson(Map<String, dynamic> json) {
    return CoursePurchasedAccess(
      hasCourse: json['hasCourse'] == true,
      sectionIds: _readStringList(json['sectionIds']),
      objectIds: _readStringList(json['objectIds']),
    );
  }
}

class CourseDetailPurchaseInfo {
  const CourseDetailPurchaseInfo({
    this.detailUrl,
    this.currentPrice,
    this.originalPrice,
    this.currentPriceLabel,
    this.originalPriceLabel,
    this.ctaLabel,
    this.isPurchased = false,
  });

  final String? detailUrl;
  final int? currentPrice;
  final int? originalPrice;
  final String? currentPriceLabel;
  final String? originalPriceLabel;
  final String? ctaLabel;
  final bool isPurchased;

  factory CourseDetailPurchaseInfo.fromApiJson(
    Map<String, dynamic> courseMap, {
    required Map<String, dynamic> ctaMap,
    required bool isPurchased,
  }) {
    final discountPrice = _asNullableInt(courseMap['discount_price']);
    final originalPrice = _asNullableInt(courseMap['original_price']);
    final effectivePrice = discountPrice != null && discountPrice > 0
        ? discountPrice
        : originalPrice;

    return CourseDetailPurchaseInfo(
      detailUrl: _asNullableStr(
        courseMap['web_url'] ?? courseMap['link'] ?? ctaMap['url'],
      ),
      currentPrice: effectivePrice,
      originalPrice: originalPrice,
      currentPriceLabel: _asNullableStr(
        courseMap['discount_price_label'] ??
            courseMap['price_label'] ??
            courseMap['original_price_label'],
      ),
      originalPriceLabel: _asNullableStr(courseMap['original_price_label']),
      ctaLabel: _asNullableStr(ctaMap['label']),
      isPurchased: isPurchased,
    );
  }

  bool get canPurchase =>
      !isPurchased && currentPrice != null && currentPrice! > 0;
  bool get canOpenWeb => detailUrl != null;
  bool get hasDiscount =>
      currentPrice != null &&
      originalPrice != null &&
      currentPrice! > 0 &&
      originalPrice! > currentPrice!;
}

class CourseDetailHero {
  const CourseDetailHero({
    required this.title,
    required this.summary,
    required this.isPurchased,
    required this.progress,
    this.thumbnailUrl,
    this.category,
    this.badgeLabel,
    this.authorName,
    this.updatedAtLabel,
    this.languageLabel,
    this.totalHoursLabel,
    this.completedLessons,
    this.totalLessons,
  });

  final String title;
  final String summary;
  final bool isPurchased;
  final int progress;
  final String? thumbnailUrl;
  final String? category;
  final String? badgeLabel;
  final String? authorName;
  final String? updatedAtLabel;
  final String? languageLabel;
  final String? totalHoursLabel;
  final int? completedLessons;
  final int? totalLessons;

  factory CourseDetailHero.fromCourseMap(
    Map<String, dynamic> map, {
    required bool isPurchased,
  }) {
    final teacher = _asMap(map['teacher']);

    String? updatedLabel;
    final updatedRaw = map['updated_at'];
    if (updatedRaw != null && updatedRaw.toString().isNotEmpty) {
      try {
        final dt = DateTime.parse(updatedRaw.toString()).toLocal();
        updatedLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        updatedLabel = null;
      }
    }

    String? totalHoursLabel;
    final durationLabel = _asNullableStr(map['duration_label']);
    if (durationLabel != null) {
      totalHoursLabel = durationLabel;
    } else {
      final hours = _asDouble(map['total_hours']);
      if (hours > 0) {
        totalHoursLabel = '${hours.toStringAsFixed(0)} giờ';
      }
    }

    String? languageLabel;
    final language = _asStr(map['language']);
    if (language == 'vi') {
      languageLabel = 'Tiếng Việt';
    } else if (language == 'en') {
      languageLabel = 'English';
    } else if (language.isNotEmpty) {
      languageLabel = language;
    }

    return CourseDetailHero(
      title: _asStr(map['title']),
      summary: _asStr(map['short_description']).isNotEmpty
          ? _asStr(map['short_description'])
          : _asStr(map['description']),
      isPurchased: isPurchased,
      progress: _asInt(map['progress']),
      thumbnailUrl: _asNullableStr(map['thumbnail'] ?? map['cover']),
      category: _asNullableStr(map['category']),
      badgeLabel: _asNullableStr(map['badge']),
      authorName: _asNullableStr(teacher['name'] ?? map['author']),
      updatedAtLabel: updatedLabel,
      languageLabel: languageLabel,
      totalHoursLabel: totalHoursLabel,
      completedLessons: _asNullableInt(map['completed_lessons']),
      totalLessons: _asNullableInt(map['total_lessons']),
    );
  }

  factory CourseDetailHero.fromFallback(HomeCourseItem course) {
    return CourseDetailHero(
      title: course.title,
      summary: course.shortDescription,
      isPurchased: (course.progress ?? 0) > 0,
      progress: course.progress ?? 0,
      thumbnailUrl: course.thumbnailUrl,
      category: course.category,
      completedLessons: course.completedLessons,
      totalLessons: course.totalLessons,
    );
  }
}

class CourseDetailMetric {
  const CourseDetailMetric({
    required this.label,
    required this.value,
    required this.iconKey,
    required this.toneKey,
  });

  final String label;
  final String value;
  final String iconKey;
  final String toneKey;

  factory CourseDetailMetric.fromJson(Map<String, dynamic> json) {
    return CourseDetailMetric(
      label: _asStr(json['label']),
      value: _asStr(json['value']),
      iconKey: _asStr(json['icon']),
      toneKey: _asStr(json['tone']),
    );
  }
}

class CourseDetailFeature {
  const CourseDetailFeature({
    required this.label,
    required this.iconKey,
    required this.toneKey,
  });

  final String label;
  final String iconKey;
  final String toneKey;

  factory CourseDetailFeature.fromHighlightJson(Map<String, dynamic> json) {
    final title = _asStr(json['title']);
    final desc = _asStr(json['description']);
    final label = desc.isNotEmpty ? '$title – $desc' : title;

    return CourseDetailFeature(
      label: label,
      iconKey: _asStr(json['icon']),
      toneKey: _asStr(json['tone']),
    );
  }
}

class CourseDetailSection {
  const CourseDetailSection({
    required this.id,
    required this.title,
    required this.description,
    required this.lectureCount,
    required this.videoCount,
    required this.docxCount,
    required this.pdfCount,
    required this.pptCount,
    required this.quizCount,
    required this.isLocked,
    required this.items,
    required this.price,
    required this.status,
    this.durationLabel,
  });

  final String id;
  final String title;
  final String description;
  final int lectureCount;
  final int videoCount;
  final int docxCount;
  final int pdfCount;
  final int pptCount;
  final int quizCount;
  final bool isLocked;
  final List<CourseDetailLearningItem> items;
  final int price;
  final String status;
  final String? durationLabel;

  factory CourseDetailSection.fromJson(Map<String, dynamic> json) {
    final sectionId = _asStr(json['id']);
    final lecturesRaw = json['lectures'];
    final quizzesRaw = json['quizzes'];

    final lectures = lecturesRaw is List
        ? lecturesRaw
              .whereType<Map>()
              .map(
                (item) => CourseDetailLearningItem.fromLecture(
                  Map<String, dynamic>.from(item),
                  sectionId: sectionId,
                ),
              )
              .toList()
        : <CourseDetailLearningItem>[];

    final quizzes = quizzesRaw is List
        ? quizzesRaw
              .whereType<Map>()
              .map(
                (item) => CourseDetailLearningItem.fromQuiz(
                  Map<String, dynamic>.from(item),
                  sectionId: sectionId,
                ),
              )
              .toList()
        : <CourseDetailLearningItem>[];

    final allItems = [...lectures, ...quizzes]
      ..sort((a, b) => a.sort.compareTo(b.sort));

    final durationRaw = _asStr(json['total_hours']);
    final durationLabel = durationRaw.isNotEmpty && durationRaw != '0min'
        ? durationRaw
        : null;

    return CourseDetailSection(
      id: sectionId,
      title: _asStr(json['title']).isNotEmpty
          ? _asStr(json['title'])
          : 'Phần học',
      description: _asStr(json['short_description']).isNotEmpty
          ? _asStr(json['short_description'])
          : 'Nội dung chi tiết của phần học.',
      lectureCount: _asInt(json['lectures_count']),
      videoCount: _asInt(json['total_lectures_video']),
      docxCount: _asInt(json['total_lectures_docx']),
      pdfCount: _asInt(json['total_lectures_pdf']),
      pptCount: _asInt(json['total_lectures_pptx']),
      quizCount: _asInt(json['total_quizzes']),
      isLocked: _asInt(json['price']) > 0,
      items: allItems,
      price: _asInt(json['price']),
      status: _asStr(json['status']),
      durationLabel: durationLabel,
    );
  }

  CourseDetailSection withResolvedAccess({
    required bool isCoursePurchased,
    required CoursePurchasedAccess purchasedAccess,
  }) {
    final sectionAccessible =
        isCoursePurchased ||
        purchasedAccess.hasCourse ||
        purchasedAccess.sectionIds.contains(id) ||
        price <= 0;

    final resolvedItems = items
        .map(
          (item) => item.withResolvedAccess(
            isCoursePurchased: isCoursePurchased,
            purchasedAccess: purchasedAccess,
            sectionAccessible: sectionAccessible,
          ),
        )
        .toList();

    return CourseDetailSection(
      id: id,
      title: title,
      description: description,
      lectureCount: lectureCount,
      videoCount: videoCount,
      docxCount: docxCount,
      pdfCount: pdfCount,
      pptCount: pptCount,
      quizCount: quizCount,
      isLocked: !sectionAccessible,
      items: resolvedItems,
      price: price,
      status: status,
      durationLabel: durationLabel,
    );
  }
}

class CourseDetailLearningItem {
  const CourseDetailLearningItem({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.typeLabel,
    required this.iconKey,
    required this.toneKey,
    required this.isLocked,
    required this.sort,
    required this.contentType,
    required this.price,
    required this.status,
    required this.canOpen,
    this.slug,
    this.minute,
    this.questionCount,
    this.badgeLabel,
    this.metaLabel,
    this.mediaMime,
    this.mediaUrl,
    this.mediaStreamingUrl,
    this.mediaHlsUrl,
    this.mediaDocumentUrl,
    this.mediaPptxUrl,
    this.subtitlePath,
    this.subtitleTracks = const [],
  });

  final String id;
  final String sectionId;
  final String title;
  final String typeLabel;
  final String iconKey;
  final String toneKey;
  final bool isLocked;
  final int sort;
  final String contentType;
  final int price;
  final String status;
  final bool canOpen;
  final String? slug;
  final int? minute;
  final int? questionCount;
  final String? badgeLabel;
  final String? metaLabel;
  final String? mediaMime;
  final String? mediaUrl;
  final String? mediaStreamingUrl;
  final String? mediaHlsUrl;
  final String? mediaDocumentUrl;
  final String? mediaPptxUrl;
  final String? subtitlePath;
  final List<CourseDetailSubtitleTrack> subtitleTracks;

  bool get isQuiz => contentType == 'quiz';
  bool get isLecture => contentType == 'lecture';
  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isExamMode => isQuiz && (minute ?? 0) > 0;

  String get _normalizedMime => (mediaMime ?? '').trim().toLowerCase();

  bool _urlHasAnyExtension(List<String> extensions) {
    final raw = preferredContentUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final path = (Uri.tryParse(raw)?.path ?? raw).toLowerCase();
    return extensions.any((extension) => path.endsWith(extension));
  }

  bool get isPdfLike {
    final mime = _normalizedMime;
    return mime == 'pdf' ||
        mime == 'application/pdf' ||
        mime.endsWith('/pdf') ||
        _urlHasAnyExtension(const ['.pdf']);
  }

  bool get isPptLike {
    final mime = _normalizedMime;
    return mime == 'ppt' ||
        mime == 'pptx' ||
        mime.contains('powerpoint') ||
        mime.contains('presentation') ||
        _urlHasAnyExtension(const ['.ppt', '.pptx']);
  }

  bool get isDocLike {
    final mime = _normalizedMime;
    return mime == 'doc' ||
        mime == 'docx' ||
        mime.contains('application/msword') ||
        mime.contains('officedocument.wordprocessingml.document') ||
        _urlHasAnyExtension(const ['.doc', '.docx']);
  }

  bool get isImageLike {
    final mime = _normalizedMime;
    return mime == 'image' ||
        mime.startsWith('image/') ||
        _urlHasAnyExtension(const [
          '.png',
          '.jpg',
          '.jpeg',
          '.gif',
          '.webp',
          '.bmp',
          '.svg',
        ]);
  }

  bool get isVideoLike {
    final mime = _normalizedMime;
    return mime.startsWith('video') ||
        mime == 'video' ||
        iconKey == 'video' ||
        _urlHasAnyExtension(const ['.mp4', '.mov', '.m4v', '.webm', '.m3u8']);
  }

  bool get looksLikeDocumentByMeta {
    final icon = iconKey.trim().toLowerCase();
    final type = typeLabel.trim().toLowerCase();
    return icon == 'document' ||
        icon == 'image' ||
        icon == 'slides' ||
        type.contains('pdf') ||
        type.contains('doc') ||
        type.contains('slide') ||
        type.contains('tài liệu') ||
        type.contains('hình ảnh') ||
        type.contains('image');
  }

  bool get prefersDocumentLikeViewer =>
      isPdfLike ||
      isDocLike ||
      isPptLike ||
      isImageLike ||
      looksLikeDocumentByMeta;

  bool get prefersLandscapeViewer => isVideoLike || prefersDocumentLikeViewer;

  String? get preferredContentUrl {
    final candidates = [
      mediaHlsUrl,
      mediaStreamingUrl,
      mediaUrl,
      mediaDocumentUrl,
      mediaPptxUrl,
    ];
    for (final raw in candidates) {
      final url = raw?.trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  factory CourseDetailLearningItem.fromLecture(
    Map<String, dynamic> json, {
    required String sectionId,
  }) {
    final media = json['media'];
    final mediaMap = _asMap(media);
    final hlsMap = _asMap(mediaMap['hls']);
    final mime = media is Map ? _asStr(media['mime']).toLowerCase() : '';

    final String iconKey;
    final String toneKey;
    final String typeLabel;

    if (mime == 'video' || mime.startsWith('video/')) {
      iconKey = 'video';
      toneKey = 'info';
      typeLabel = 'Video';
    } else if (mime == 'pdf' ||
        mime == 'application/pdf' ||
        mime.endsWith('/pdf')) {
      iconKey = 'document';
      toneKey = 'danger';
      typeLabel = 'PDF';
    } else if (mime == 'pptx' ||
        mime == 'ppt' ||
        mime.contains('powerpoint') ||
        mime.contains('presentation')) {
      iconKey = 'slides';
      toneKey = 'warning';
      typeLabel = 'Slide';
    } else if (mime == 'docx' ||
        mime == 'doc' ||
        mime.contains('application/msword') ||
        mime.contains('officedocument.wordprocessingml.document')) {
      iconKey = 'document';
      toneKey = 'info';
      typeLabel = 'Tài liệu';
    } else if (mime == 'image' || mime.startsWith('image/')) {
      iconKey = 'image';
      toneKey = 'info';
      typeLabel = 'Hình ảnh';
    } else {
      iconKey = 'lessons';
      toneKey = 'success';
      typeLabel = 'Bài giảng';
    }

    final durationMin = _asInt(json['duration_minutes']);
    final badgeLabel = durationMin > 0 ? '$durationMin phút' : null;
    final price = _asInt(json['price']);
    final status = _asStr(json['status']);
    final subtitlePathsRaw = json['subtitle_paths'];
    final subtitleTracks = subtitlePathsRaw is List
        ? subtitlePathsRaw
              .map(CourseDetailSubtitleTrack.fromJson)
              .where((item) => item.path.isNotEmpty)
              .toList()
        : <CourseDetailSubtitleTrack>[];

    return CourseDetailLearningItem(
      id: _asStr(json['id']),
      sectionId: sectionId,
      title: _asStr(json['title']).isNotEmpty
          ? _asStr(json['title'])
          : 'Bài giảng',
      typeLabel: typeLabel,
      iconKey: iconKey,
      toneKey: toneKey,
      isLocked: price > 0,
      sort: _asInt(json['sort']),
      contentType: 'lecture',
      price: price,
      status: status,
      canOpen: price <= 0 && status.toLowerCase() != 'draft',
      slug: _asNullableStr(json['slug']),
      badgeLabel: badgeLabel,
      mediaMime: mime.isNotEmpty ? mime : _asNullableStr(mediaMap['mime']),
      mediaUrl: _normalizeAssetUrl(_asNullableStr(json['media_url'])),
      mediaStreamingUrl: _normalizeDirectMediaUrl(
        _asNullableStr(mediaMap['url']) ?? _asNullableStr(mediaMap['path']),
      ),
      mediaHlsUrl: _normalizeDirectMediaUrl(_asNullableStr(hlsMap['master'])),
      mediaDocumentUrl: _normalizeAssetUrl(
        _asNullableStr(json['media_url_document']),
      ),
      mediaPptxUrl: _normalizeAssetUrl(_asNullableStr(json['media_url_pptx'])),
      subtitlePath: _normalizeAssetUrl(_asNullableStr(json['subtitle_path'])),
      subtitleTracks: subtitleTracks,
    );
  }

  factory CourseDetailLearningItem.fromQuiz(
    Map<String, dynamic> json, {
    required String sectionId,
  }) {
    final minute = _asInt(json['minute']);
    final badgeLabel = minute > 0 ? '$minute phút' : null;

    final qCount = _asInt(json['question_count']);
    final metaLabel = qCount > 0 ? 'Gồm $qCount câu hỏi' : null;

    final price = _asInt(json['price']);
    final status = _asStr(json['status']);

    return CourseDetailLearningItem(
      id: _asStr(json['id']),
      sectionId: sectionId,
      title: _asStr(json['name']).isNotEmpty ? _asStr(json['name']) : 'Đề thi',
      typeLabel: 'Đề thi',
      iconKey: 'exam',
      toneKey: 'info',
      isLocked: price > 0,
      sort: _asInt(json['sort']),
      contentType: 'quiz',
      price: price,
      status: status,
      canOpen: price <= 0 && status.toLowerCase() != 'draft',
      slug: _asNullableStr(json['slug']),
      minute: minute,
      questionCount: qCount > 0 ? qCount : null,
      badgeLabel: badgeLabel,
      metaLabel: metaLabel,
    );
  }

  CourseDetailLearningItem withResolvedAccess({
    required bool isCoursePurchased,
    required CoursePurchasedAccess purchasedAccess,
    required bool sectionAccessible,
  }) {
    final hasObjectAccess = purchasedAccess.objectIds.contains(id);
    final hasSectionAccess =
        sectionAccessible || purchasedAccess.sectionIds.contains(sectionId);
    final canAccess =
        isCoursePurchased ||
        purchasedAccess.hasCourse ||
        hasSectionAccess ||
        hasObjectAccess ||
        price <= 0;

    final canOpen = canAccess && !isDraft;

    return CourseDetailLearningItem(
      id: id,
      sectionId: sectionId,
      title: title,
      typeLabel: typeLabel,
      iconKey: iconKey,
      toneKey: toneKey,
      isLocked: !canAccess,
      sort: sort,
      contentType: contentType,
      price: price,
      status: status,
      canOpen: canOpen,
      slug: slug,
      minute: minute,
      questionCount: questionCount,
      badgeLabel: badgeLabel,
      metaLabel: metaLabel,
      mediaMime: mediaMime,
      mediaUrl: mediaUrl,
      mediaStreamingUrl: mediaStreamingUrl,
      mediaHlsUrl: mediaHlsUrl,
      mediaDocumentUrl: mediaDocumentUrl,
      mediaPptxUrl: mediaPptxUrl,
      subtitlePath: subtitlePath,
      subtitleTracks: subtitleTracks,
    );
  }
}

class CourseDetailSubtitleTrack {
  const CourseDetailSubtitleTrack({
    required this.path,
    this.language,
    this.s3Path,
  });

  final String path;
  final String? language;
  final String? s3Path;

  String get normalizedLanguage => (language ?? '').trim().toLowerCase();

  String get shortLabel {
    switch (normalizedLanguage) {
      case 'vi':
        return 'VI';
      case 'en':
        return 'EN';
      default:
        return 'SUB';
    }
  }

  String get longLabel {
    switch (normalizedLanguage) {
      case 'vi':
        return 'Tiếng Việt';
      case 'en':
        return 'Tiếng Anh';
      default:
        return 'Phụ đề';
    }
  }

  static CourseDetailSubtitleTrack fromJson(dynamic raw) {
    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      return CourseDetailSubtitleTrack(
        path: _normalizeAssetUrl(_asNullableStr(map['path'])) ?? '',
        language: _asNullableStr(map['language']),
        s3Path: _asNullableStr(map['s3_path']),
      );
    }

    if (raw is String) {
      return CourseDetailSubtitleTrack(path: _normalizeAssetUrl(raw) ?? raw);
    }

    return const CourseDetailSubtitleTrack(path: '');
  }
}

class CourseDetailResolvedContent {
  const CourseDetailResolvedContent({
    required this.uri,
    required this.kind,
    this.fallbackPageUri,
    this.subtitleTracks = const [],
  });

  final Uri uri;
  final String kind;
  final Uri? fallbackPageUri;
  final List<CourseDetailSubtitleTrack> subtitleTracks;

  bool get isVideo => kind == 'video';
  bool get isWebView => !isVideo;
}

class CourseLectureProgressStatus {
  const CourseLectureProgressStatus({
    required this.isCompleted,
    required this.watchedSeconds,
  });

  final bool isCompleted;
  final int watchedSeconds;

  static const empty = CourseLectureProgressStatus(
    isCompleted: false,
    watchedSeconds: 0,
  );

  factory CourseLectureProgressStatus.fromJson(Map<String, dynamic> json) {
    return CourseLectureProgressStatus(
      isCompleted: json['is_completed'] == true,
      watchedSeconds: _asInt(json['watched_seconds']),
    );
  }

  CourseLectureProgressStatus copyWith({
    bool? isCompleted,
    int? watchedSeconds,
  }) {
    return CourseLectureProgressStatus(
      isCompleted: isCompleted ?? this.isCompleted,
      watchedSeconds: watchedSeconds ?? this.watchedSeconds,
    );
  }
}

class BalancePurchaseResult {
  const BalancePurchaseResult({
    required this.purchased,
    required this.alreadyPurchased,
    required this.balance,
    required this.message,
  });

  final bool purchased;
  final bool alreadyPurchased;
  final int balance;
  final String message;

  factory BalancePurchaseResult.fromJson(Map<String, dynamic> json) {
    return BalancePurchaseResult(
      purchased: json['purchased'] == true,
      alreadyPurchased: json['already_purchased'] == true,
      balance: _asInt(json['balance']),
      message: _asStr(json['message']).isNotEmpty
          ? _asStr(json['message'])
          : 'Thao tác hoàn tất.',
    );
  }
}

String _asStr(dynamic value) => (value ?? '').toString().trim();

String? _asNullableStr(dynamic value) {
  final text = _asStr(value);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

String? _normalizeAssetUrl(String? value) {
  if (value == null) {
    return null;
  }

  final raw = value.trim();
  if (raw.isEmpty) {
    return null;
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  if (raw.startsWith('//')) {
    return 'https:$raw';
  }

  return raw;
}

String? _normalizeDirectMediaUrl(String? value) {
  if (value == null) {
    return null;
  }

  final raw = value.trim();
  if (raw.isEmpty) {
    return null;
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return raw;
  }

  if (raw.startsWith('//')) {
    return 'https:$raw';
  }

  return null;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
