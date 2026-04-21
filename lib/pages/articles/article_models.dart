class ArticleListResponse {
  const ArticleListResponse({
    required this.items,
    required this.pagination,
  });

  final List<ArticleSummary> items;
  final ArticlePagination pagination;

  factory ArticleListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    final paginationRaw = json['pagination'];

    return ArticleListResponse(
      items: itemsRaw is List
          ? itemsRaw
                .whereType<Map>()
                .map(
                  (item) => ArticleSummary.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
      pagination: paginationRaw is Map
          ? ArticlePagination.fromJson(
              paginationRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : ArticlePagination.empty,
    );
  }
}

class ArticlePagination {
  const ArticlePagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });

  static const empty = ArticlePagination(
    currentPage: 1,
    lastPage: 1,
    perPage: 0,
    total: 0,
    hasMore: false,
  );

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMore;

  factory ArticlePagination.fromJson(Map<String, dynamic> json) {
    return ArticlePagination(
      currentPage: _asInt(json['current_page'], fallback: 1),
      lastPage: _asInt(json['last_page'], fallback: 1),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      hasMore: json['has_more'] == true,
    );
  }
}

class ArticleDetailResponse {
  const ArticleDetailResponse({
    required this.article,
    required this.related,
  });

  final ArticleDetail article;
  final List<ArticleSummary> related;

  factory ArticleDetailResponse.fromJson(Map<String, dynamic> json) {
    final articleRaw = json['article'];
    final relatedRaw = json['related'];

    return ArticleDetailResponse(
      article: articleRaw is Map
          ? ArticleDetail.fromJson(
              articleRaw.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const ArticleDetail.empty(),
      related: relatedRaw is List
          ? relatedRaw
                .whereType<Map>()
                .map(
                  (item) => ArticleSummary.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.isPinned,
    required this.createdAt,
    required this.createdAtLabel,
    required this.webPath,
  });

  const ArticleSummary.empty()
    : id = '',
      slug = '',
      title = '',
      description = '',
      imageUrl = null,
      type = '',
      isPinned = false,
      createdAt = null,
      createdAtLabel = null,
      webPath = null;

  final String id;
  final String slug;
  final String title;
  final String description;
  final String? imageUrl;
  final String type;
  final bool isPinned;
  final String? createdAt;
  final String? createdAtLabel;
  final String? webPath;

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: _asString(json['id']),
      slug: _asString(json['slug']),
      title: _asString(json['title'], fallback: 'Bài viết'),
      description: _asString(json['description']),
      imageUrl: _asNullableString(json['image_url']),
      type: _asString(json['type']),
      isPinned: json['is_pinned'] == true,
      createdAt: _asNullableString(json['created_at']),
      createdAtLabel: _asNullableString(json['created_at_label']),
      webPath: _asNullableString(json['web_path']),
    );
  }
}

class ArticleDetail extends ArticleSummary {
  const ArticleDetail({
    required super.id,
    required super.slug,
    required super.title,
    required super.description,
    required super.imageUrl,
    required super.type,
    required super.isPinned,
    required super.createdAt,
    required super.createdAtLabel,
    required super.webPath,
    required this.content,
    required this.updatedAt,
    required this.updatedAtLabel,
  });

  const ArticleDetail.empty()
    : content = '',
      updatedAt = null,
      updatedAtLabel = null,
      super.empty();

  final String content;
  final String? updatedAt;
  final String? updatedAtLabel;

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final base = ArticleSummary.fromJson(json);
    return ArticleDetail(
      id: base.id,
      slug: base.slug,
      title: base.title,
      description: base.description,
      imageUrl: base.imageUrl,
      type: base.type,
      isPinned: base.isPinned,
      createdAt: base.createdAt,
      createdAtLabel: base.createdAtLabel,
      webPath: base.webPath,
      content: _asString(json['content']),
      updatedAt: _asNullableString(json['updated_at']),
      updatedAtLabel: _asNullableString(json['updated_at_label']),
    );
  }
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }

  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _asNullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
