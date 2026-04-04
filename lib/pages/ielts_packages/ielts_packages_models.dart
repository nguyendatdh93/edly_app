import 'package:edupen/pages/home/home_models.dart';

class IeltsPackagesData {
  const IeltsPackagesData({
    required this.root,
    required this.sections,
    required this.allCourses,
  });

  final IeltsCollectionRoot root;
  final List<IeltsCollectionSection> sections;
  final List<HomeCourseItem> allCourses;

  factory IeltsPackagesData.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final allCoursesRaw = json['all_courses'];
    return IeltsPackagesData(
      root: IeltsCollectionRoot.fromJson(_asMap(json['root'])),
      sections: sectionsRaw is List
          ? sectionsRaw
                .whereType<Map>()
                .map(
                  (item) => IeltsCollectionSection.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      allCourses: allCoursesRaw is List
          ? allCoursesRaw
                .whereType<Map>()
                .map((item) => HomeCourseItem.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
  }
}

class IeltsCollectionRoot {
  const IeltsCollectionRoot({
    required this.id,
    required this.title,
    required this.slug,
  });

  final String id;
  final String title;
  final String slug;

  factory IeltsCollectionRoot.fromJson(Map<String, dynamic> json) {
    return IeltsCollectionRoot(
      id: _asText(json['id']),
      title: _asText(json['title']),
      slug: _asText(json['slug']),
    );
  }
}

class IeltsCollectionSection {
  const IeltsCollectionSection({
    required this.id,
    required this.title,
    required this.slug,
    required this.courses,
  });

  final String id;
  final String title;
  final String slug;
  final List<HomeCourseItem> courses;

  factory IeltsCollectionSection.fromJson(Map<String, dynamic> json) {
    final coursesRaw = json['courses'];
    return IeltsCollectionSection(
      id: _asText(json['id']),
      title: _asText(json['title']),
      slug: _asText(json['slug']),
      courses: coursesRaw is List
          ? coursesRaw
                .whereType<Map>()
                .map((item) => HomeCourseItem.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
  }
}

String _asText(dynamic value) => (value ?? '').toString().trim();

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}
