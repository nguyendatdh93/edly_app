class TeacherDashboardData {
  const TeacherDashboardData({
    required this.teacher,
    required this.assignmentActivity,
    required this.recentAssignments,
    required this.classrooms,
    required this.latestQuizzes,
    required this.announcements,
    required this.links,
  });

  final TeacherAccess teacher;
  final TeacherAssignmentActivity assignmentActivity;
  final List<TeacherAssignmentItem> recentAssignments;
  final List<TeacherClassroomItem> classrooms;
  final List<TeacherQuizItem> latestQuizzes;
  final List<TeacherAnnouncementItem> announcements;
  final TeacherLinks links;

  factory TeacherDashboardData.fromJson(Map<String, dynamic> json) {
    return TeacherDashboardData(
      teacher: TeacherAccess.fromJson(_asMap(json['teacher'])),
      assignmentActivity: TeacherAssignmentActivity.fromJson(
        _asMap(json['assignment_activity']),
      ),
      recentAssignments: _asList(json['recent_assignments'])
          .map((item) => TeacherAssignmentItem.fromJson(_asMap(item)))
          .toList(growable: false),
      classrooms: _asList(json['classrooms'])
          .map((item) => TeacherClassroomItem.fromJson(_asMap(item)))
          .toList(growable: false),
      latestQuizzes: _asList(json['latest_quizzes'])
          .map((item) => TeacherQuizItem.fromJson(_asMap(item)))
          .toList(growable: false),
      announcements: _asList(json['announcements'])
          .map((item) => TeacherAnnouncementItem.fromJson(_asMap(item)))
          .toList(growable: false),
      links: TeacherLinks.fromJson(_asMap(json['links'])),
    );
  }
}

class TeacherCourseLibraryData {
  const TeacherCourseLibraryData({required this.items});

  final List<TeacherCourseItem> items;

  factory TeacherCourseLibraryData.fromJson(Map<String, dynamic> json) {
    return TeacherCourseLibraryData(
      items: _asList(json['items'])
          .map((item) => TeacherCourseItem.fromJson(_asMap(item)))
          .toList(growable: false),
    );
  }
}

class TeacherCourseItem {
  const TeacherCourseItem({
    required this.id,
    required this.uuid,
    required this.slug,
    required this.title,
    required this.description,
    required this.discountPrice,
    required this.originalPrice,
    required this.totalQuizzes,
    required this.totalDocuments,
    required this.totalLectures,
    required this.isPurchased,
    required this.canCreateSample,
    required this.canEditSample,
    this.thumbnailUrl,
  });

  final String id;
  final String uuid;
  final String slug;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final int discountPrice;
  final int originalPrice;
  final int totalQuizzes;
  final int totalDocuments;
  final int totalLectures;
  final bool isPurchased;
  final bool canCreateSample;
  final bool canEditSample;

  factory TeacherCourseItem.fromJson(Map<String, dynamic> json) {
    return TeacherCourseItem(
      id: _asString(json['id']),
      uuid: _asString(json['uuid'], fallback: _asString(json['id'])),
      slug: _asString(json['slug']),
      title: _asString(json['title'], fallback: 'Khóa học'),
      description: _asString(json['description']),
      thumbnailUrl: _asNullableString(json['thumbnail']),
      discountPrice: _asInt(json['discount_price']),
      originalPrice: _asInt(json['original_price']),
      totalQuizzes: _asInt(json['total_quizzes']),
      totalDocuments: _asInt(json['total_documents']),
      totalLectures: _asInt(json['total_lectures']),
      isPurchased: json['is_purchased'] == true,
      canCreateSample: json['can_create_sample'] == true,
      canEditSample: json['can_edit_sample'] == true,
    );
  }

  int get currentPrice => discountPrice > 0 ? discountPrice : originalPrice;
}

class TeacherAccess {
  const TeacherAccess({
    required this.isTeacher,
    required this.isAdmin,
    required this.canManageAnnouncements,
  });

  final bool isTeacher;
  final bool isAdmin;
  final bool canManageAnnouncements;

  factory TeacherAccess.fromJson(Map<String, dynamic> json) {
    return TeacherAccess(
      isTeacher: json['is_teacher'] == true,
      isAdmin: json['is_admin'] == true,
      canManageAnnouncements: json['can_manage_announcements'] == true,
    );
  }
}

class TeacherAssignmentActivity {
  const TeacherAssignmentActivity({
    required this.completionPercent,
    required this.averageAssignedStudents,
  });

  final int completionPercent;
  final int averageAssignedStudents;

  factory TeacherAssignmentActivity.fromJson(Map<String, dynamic> json) {
    return TeacherAssignmentActivity(
      completionPercent: _asInt(json['latest_two_completion_percent']),
      averageAssignedStudents: _asInt(json['average_assigned_students']),
    );
  }
}

class TeacherAssignmentItem {
  const TeacherAssignmentItem({
    required this.id,
    required this.title,
    required this.submitted,
    required this.assigned,
    required this.completionPercent,
    this.classroomId,
    this.publishedAtLabel,
    this.webPath,
  });

  final String id;
  final String title;
  final int submitted;
  final int assigned;
  final int completionPercent;
  final String? classroomId;
  final String? publishedAtLabel;
  final String? webPath;

  factory TeacherAssignmentItem.fromJson(Map<String, dynamic> json) {
    return TeacherAssignmentItem(
      id: _asString(json['id']),
      classroomId: _asNullableString(json['classroom_id']),
      title: _asString(json['title'], fallback: 'Bài giao chưa có tiêu đề'),
      publishedAtLabel: _asNullableString(json['published_at_label']),
      submitted: _asInt(json['submitted']),
      assigned: _asInt(json['assigned']),
      completionPercent: _asInt(json['completion_percent']),
      webPath: _asNullableString(json['web_path']),
    );
  }
}

class TeacherClassroomItem {
  const TeacherClassroomItem({
    required this.id,
    required this.name,
    required this.studentCount,
    this.schoolYear,
    this.webPath,
  });

  final String id;
  final String name;
  final int studentCount;
  final String? schoolYear;
  final String? webPath;

  factory TeacherClassroomItem.fromJson(Map<String, dynamic> json) {
    return TeacherClassroomItem(
      id: _asString(json['id']),
      name: _asString(json['name'], fallback: 'Lớp học'),
      schoolYear: _asNullableString(json['school_year']),
      studentCount: _asInt(json['student_count']),
      webPath: _asNullableString(json['web_path']),
    );
  }
}

class TeacherQuizItem {
  const TeacherQuizItem({
    required this.id,
    required this.name,
    this.slug,
    this.createdAtLabel,
    this.webPath,
  });

  final String id;
  final String name;
  final String? slug;
  final String? createdAtLabel;
  final String? webPath;

  factory TeacherQuizItem.fromJson(Map<String, dynamic> json) {
    return TeacherQuizItem(
      id: _asString(json['id']),
      slug: _asNullableString(json['slug']),
      name: _asString(json['name'], fallback: 'Đề chưa đặt tên'),
      createdAtLabel: _asNullableString(json['created_at_label']),
      webPath: _asNullableString(json['web_path']),
    );
  }
}

class TeacherAnnouncementItem {
  const TeacherAnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    this.createdAtLabel,
    this.actionUrl,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String content;
  final String? createdAtLabel;
  final String? actionUrl;
  final String? actionLabel;

  factory TeacherAnnouncementItem.fromJson(Map<String, dynamic> json) {
    return TeacherAnnouncementItem(
      id: _asString(json['id']),
      title: _asString(json['title'], fallback: 'Thông báo'),
      content: _asString(json['content']),
      createdAtLabel: _asNullableString(json['created_at_label']),
      actionUrl: _asNullableString(json['action_url']),
      actionLabel: _asNullableString(json['action_label']),
    );
  }
}

class TeacherLinks {
  const TeacherLinks({
    required this.dashboard,
    required this.classrooms,
    required this.courseLibrary,
    required this.registerTeacher,
  });

  final String dashboard;
  final String classrooms;
  final String courseLibrary;
  final String registerTeacher;

  factory TeacherLinks.fromJson(Map<String, dynamic> json) {
    return TeacherLinks(
      dashboard: _asString(json['dashboard'], fallback: '/dashboard'),
      classrooms: _asString(json['classrooms'], fallback: '/classroom'),
      courseLibrary: _asString(
        json['course_library'],
        fallback: '/kho-tai-lieu',
      ),
      registerTeacher: _asString(
        json['register_teacher'],
        fallback: '/confirm',
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const [];
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
