import 'package:edupen/pages/home/home_models.dart';

class SatPackagesData {
  const SatPackagesData({
    required this.root,
    required this.sections,
    required this.allCourses,
  });

  final SatCollectionRoot root;
  final List<SatCollectionSection> sections;
  final List<HomeCourseItem> allCourses;

  factory SatPackagesData.fromJson(Map<String, dynamic> json) {
    final sectionsRaw = json['sections'];
    final allCoursesRaw = json['all_courses'];

    return SatPackagesData(
      root: SatCollectionRoot.fromJson(_asMap(json['root'])),
      sections: sectionsRaw is List
          ? sectionsRaw
                .whereType<Map>()
                .map(
                  (item) => SatCollectionSection.fromJson(
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

class SatCollectionRoot {
  const SatCollectionRoot({
    required this.id,
    required this.title,
    required this.slug,
  });

  final String id;
  final String title;
  final String slug;

  factory SatCollectionRoot.fromJson(Map<String, dynamic> json) {
    return SatCollectionRoot(
      id: _asText(json['id']),
      title: _asText(json['title']),
      slug: _asText(json['slug']),
    );
  }
}

class SatCollectionSection {
  const SatCollectionSection({
    required this.id,
    required this.title,
    required this.slug,
    required this.courses,
  });

  final String id;
  final String title;
  final String slug;
  final List<HomeCourseItem> courses;

  factory SatCollectionSection.fromJson(Map<String, dynamic> json) {
    final coursesRaw = json['courses'];
    return SatCollectionSection(
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
