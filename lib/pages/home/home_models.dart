class HomeDashboardData {
  const HomeDashboardData({
    required this.purchased,
    required this.featured,
    required this.recent,
    required this.categories,
  });

  final List<HomeCourseItem> purchased;
  final List<HomeCourseItem> featured;
  final List<HomeCourseItem> recent;
  final List<HomeCategorySection> categories;

  factory HomeDashboardData.fromJson(Map<String, dynamic> json) {
    return HomeDashboardData(
      purchased: _readCourseList(json['purchased']),
      featured: _readCourseList(json['featured']),
      recent: _readCourseList(json['recent']),
      categories: _readCategoryList(json['categories']),
    );
  }

  bool get isEmpty {
    return purchased.isEmpty &&
        featured.isEmpty &&
        recent.isEmpty &&
        categories.isEmpty;
  }

  static List<HomeCourseItem> _readCourseList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) => HomeCourseItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<HomeCategorySection> _readCategoryList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              HomeCategorySection.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}

class HomeCollectionMenuItem {
  const HomeCollectionMenuItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.children,
  });

  final String id;
  final String title;
  final String slug;
  final List<HomeCollectionMenuItem> children;

  factory HomeCollectionMenuItem.fromJson(Map<String, dynamic> json) {
    return HomeCollectionMenuItem(
      id: _readString(json['id']),
      title: _readString(json['title']),
      slug: _readString(json['slug']),
      children: _readMenuChildren(
        json['children_recursive'] ??
            json['childrenRecursive'] ??
            json['children'],
      ),
    );
  }

  bool get hasChildren => children.isNotEmpty;

  static List<HomeCollectionMenuItem> readList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              HomeCollectionMenuItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static List<HomeCollectionMenuItem> _readMenuChildren(dynamic value) {
    return readList(value);
  }
}

class HomeCollectionCourseListData {
  const HomeCollectionCourseListData({
    required this.collection,
    required this.courses,
  });

  final HomeCollectionSummary collection;
  final List<HomeCourseItem> courses;

  factory HomeCollectionCourseListData.fromJson(Map<String, dynamic> json) {
    final collectionRaw = json['collection'] ?? json['root'];
    final coursesRaw = json['courses'] ?? json['all_courses'];

    return HomeCollectionCourseListData(
      collection: HomeCollectionSummary.fromJson(
        collectionRaw is Map<String, dynamic>
            ? collectionRaw
            : collectionRaw is Map
            ? collectionRaw.map((key, value) => MapEntry(key.toString(), value))
            : const {},
      ),
      courses: coursesRaw is List
          ? coursesRaw
                .whereType<Map>()
                .map(
                  (item) =>
                      HomeCourseItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class HomeCollectionSummary {
  const HomeCollectionSummary({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
  });

  final String id;
  final String title;
  final String slug;
  final String description;

  factory HomeCollectionSummary.fromJson(Map<String, dynamic> json) {
    return HomeCollectionSummary(
      id: _readString(json['id']),
      title: _readString(json['title']),
      slug: _readString(json['slug']),
      description: _readString(json['description']),
    );
  }
}

class HomeCourseItem {
  const HomeCourseItem({
    required this.id,
    required this.publicId,
    required this.slug,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.linkUrl,
    this.category,
    this.progress,
    this.totalLessons,
    this.completedLessons,
  });

  final String id;
  final String publicId;
  final String slug;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? linkUrl;
  final String? category;
  final int? progress;
  final int? totalLessons;
  final int? completedLessons;

  factory HomeCourseItem.fromJson(Map<String, dynamic> json) {
    return HomeCourseItem(
      id: _readString(json['id']),
      publicId: _readString(json['public_id']),
      slug: _readString(json['slug']),
      title: _readString(json['title']),
      description: _readString(json['description']),
      thumbnailUrl: _readNullableString(json['thumbnail']),
      linkUrl: _readNullableString(json['link']),
      category: _readNullableString(json['category']),
      progress: _readNullableInt(json['progress']),
      totalLessons: _readNullableInt(json['total_lessons']),
      completedLessons: _readNullableInt(json['completed_lessons']),
    );
  }

  String get shortDescription {
    if (description.trim().isNotEmpty) {
      return description.trim();
    }

    return 'Khóa học đang chờ bạn tiếp tục.';
  }
}

class HomeCategorySection {
  const HomeCategorySection({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.courses,
    this.viewAllUrl,
  });

  final String id;
  final String title;
  final String slug;
  final String description;
  final String? viewAllUrl;
  final List<HomeCourseItem> courses;

  factory HomeCategorySection.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];

    return HomeCategorySection(
      id: _readString(json['id']),
      title: _readString(json['title']),
      slug: _readString(json['slug']),
      description: _readString(json['description']),
      viewAllUrl: _readNullableString(json['view_all_url']),
      courses: rawCourses is List
          ? rawCourses
                .whereType<Map>()
                .map(
                  (item) =>
                      HomeCourseItem.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }

  String get subtitle {
    if (description.trim().isNotEmpty) {
      return description.trim();
    }

    return 'Khám phá các khóa học mới nhất của $title';
  }
}

String _readString(dynamic value) {
  return (value ?? '').toString().trim();
}

String? _readNullableString(dynamic value) {
  final text = _readString(value);
  return text.isEmpty ? null : text;
}

int? _readNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
