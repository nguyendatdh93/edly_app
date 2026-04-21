import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/articles/article_detail_view.dart';
import 'package:edly/pages/articles/article_models.dart';
import 'package:edly/pages/articles/article_repository.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:edly/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';

class ArticleListView extends StatefulWidget {
  const ArticleListView({
    super.key,
    this.title = 'Bài viết',
    this.currentTab = LearningDockTab.account,
  });

  final String title;
  final LearningDockTab currentTab;

  @override
  State<ArticleListView> createState() => _ArticleListViewState();
}

class _ArticleListViewState extends State<ArticleListView> {
  late Future<void> _future;
  final List<ArticleSummary> _items = <ArticleSummary>[];
  final TextEditingController _searchController = TextEditingController();
  ArticlePagination _pagination = ArticlePagination.empty;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedType = '';

  @override
  void initState() {
    super.initState();
    _future = _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final response = await ArticleRepository.instance.fetchArticles();
    if (!mounted) {
      return;
    }

    setState(() {
      _items
        ..clear()
        ..addAll(response.items);
      _pagination = response.pagination;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadInitial();
    });
    await _future;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_pagination.hasMore) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await ArticleRepository.instance.fetchArticles(
        page: _pagination.currentPage + 1,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(response.items);
        _pagination = response.pagination;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _openArticle(ArticleSummary article) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ArticleDetailView(slug: article.slug, initialTitle: article.title),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
      } else {
        _isSearching = true;
      }
    });
  }

  List<String> get _availableTypes {
    final values = _items
        .map((item) => item.type.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<ArticleSummary> get _filteredItems {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    return _items.where((item) {
      final matchesType =
          _selectedType.isEmpty || item.type.trim() == _selectedType;
      if (!matchesType) {
        return false;
      }

      if (normalizedQuery.isEmpty) {
        return true;
      }

      final title = item.title.toLowerCase();
      final description = item.description.toLowerCase();
      final type = item.type.toLowerCase();
      return title.contains(normalizedQuery) ||
          description.contains(normalizedQuery) ||
          type.contains(normalizedQuery);
    }).toList(growable: false);
  }

  String _typeLabel(String type) {
    final trimmed = type.trim();
    if (trimmed.isEmpty) {
      return 'Tất cả';
    }

    return trimmed
        .split(RegExp(r'[_\- ]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return lower[0].toUpperCase() + lower.substring(1);
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Scaffold(
      backgroundColor: HomePalette.background,
      bottomNavigationBar: LearningDockBar(currentTab: widget.currentTab),
      appBar: AppBar(
        titleSpacing: 20,
        title: _isSearching
            ? Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0F172A),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm bài viết',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 21,
                      color: Color(0xFF64748B),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    suffixIcon: _searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            splashRadius: 18,
                          ),
                    hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: HomePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _toggleSearch,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: HomePalette.textPrimary,
              ),
              icon: Icon(
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              _items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && _items.isEmpty) {
            return _ArticleListError(
              message: _messageFromError(snapshot.error),
              onRetry: _reload,
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (_availableTypes.isNotEmpty) ...[
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: _selectedType.isEmpty,
                            onSelected: (_) {
                              setState(() {
                                _selectedType = '';
                              });
                            },
                          ),
                        ),
                        ..._availableTypes.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_typeLabel(type)),
                              selected: _selectedType == type,
                              onSelected: (_) {
                                setState(() {
                                  _selectedType = _selectedType == type
                                      ? ''
                                      : type;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_searchQuery.trim().isNotEmpty || _selectedType.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${filteredItems.length} kết quả',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomePalette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (filteredItems.isEmpty)
                  const _ArticleListEmpty(
                    message: 'Không tìm thấy bài viết phù hợp.',
                  )
                else
                  ...List.generate(filteredItems.length, (index) {
                    final article = filteredItems[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            index == filteredItems.length - 1 &&
                                !_pagination.hasMore
                            ? 0
                            : 12,
                      ),
                      child: _ArticleCard(
                        article: article,
                        typeLabel: _typeLabel(article.type),
                        onTap: () => _openArticle(article),
                      ),
                    );
                  }),
                if (_pagination.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton(
                      onPressed: _isLoadingMore ? null : _loadMore,
                      child: _isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Xem thêm'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không tải được danh sách bài viết.';
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.typeLabel,
    required this.onTap,
  });

  final ArticleSummary article;
  final String typeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ArticleCover(imageUrl: article.imageUrl),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (article.isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4D6),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Nổi bật',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFFB45309),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        if (article.type.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              typeLabel,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        if ((article.createdAtLabel ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              article.createdAtLabel!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: HomePalette.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (article.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HomePalette.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleCover extends StatelessWidget {
  const _ArticleCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: hasImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _ArticleCoverFallback();
                },
              )
            : const _ArticleCoverFallback(),
      ),
    );
  }
}

class _ArticleCoverFallback extends StatelessWidget {
  const _ArticleCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF0FF), Color(0xFFD6E4FF)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.article_outlined,
          size: 42,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _ArticleListEmpty extends StatelessWidget {
  const _ArticleListEmpty({
    this.message = 'Chưa có bài viết để hiển thị.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.article_outlined,
            size: 42,
            color: HomePalette.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomePalette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleListError extends StatelessWidget {
  const _ArticleListError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: HomePalette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
