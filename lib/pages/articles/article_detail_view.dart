import 'dart:convert';

import 'package:edly/core/config/api_config.dart';
import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/articles/article_models.dart';
import 'package:edly/pages/articles/article_repository.dart';
import 'package:edly/pages/home/home_constants.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ArticleDetailView extends StatefulWidget {
  const ArticleDetailView({
    super.key,
    required this.slug,
    this.initialTitle,
  });

  final String slug;
  final String? initialTitle;

  @override
  State<ArticleDetailView> createState() => _ArticleDetailViewState();
}

class _ArticleDetailViewState extends State<ArticleDetailView> {
  late Future<ArticleDetailResponse> _future;
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white);
  }

  Future<ArticleDetailResponse> _loadDetail() {
    return ArticleRepository.instance.fetchArticleDetail(widget.slug);
  }

  Future<void> _reload() async {
    final future = _loadDetail();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _loadHtml(ArticleDetail article) {
    return _webViewController.loadHtmlString(
      _buildArticleHtml(article),
      baseUrl: ApiConfig.webBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        title: Text(
          widget.initialTitle?.trim().isNotEmpty == true
              ? widget.initialTitle!
              : 'Chi tiết bài viết',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<ArticleDetailResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ArticleDetailError(
              message: _messageFromError(snapshot.error),
              onRetry: _reload,
            );
          }

          final detail = snapshot.data ?? const ArticleDetailResponse(
            article: ArticleDetail.empty(),
            related: [],
          );
          _loadHtml(detail.article);

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.article.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: HomePalette.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if ((detail.article.updatedAtLabel ??
                            detail.article.createdAtLabel)
                        case final String label
                        when label.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HomePalette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: WebViewWidget(controller: _webViewController),
              ),
            ],
          );
        },
      ),
    );
  }

  String _messageFromError(Object? error) {
    if (error is AppException) {
      return error.message;
    }

    return 'Không tải được chi tiết bài viết.';
  }
}

class _ArticleDetailError extends StatelessWidget {
  const _ArticleDetailError({required this.message, required this.onRetry});

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

String _buildArticleHtml(ArticleDetail article) {
  final title = htmlEscape.convert(article.title);
  final description = htmlEscape.convert(article.description);
  final image = article.imageUrl?.trim();
  final content = article.content.trim().isEmpty
      ? '<p>${htmlEscape.convert(article.description)}</p>'
      : article.content;

  final imageMarkup = image == null || image.isEmpty
      ? ''
      : '<img src="${htmlEscape.convert(image)}" alt="$title" class="hero-image" />';

  return '''
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$title</title>
  <meta name="description" content="$description">
  <style>
    :root {
      color-scheme: light;
      --bg: #ffffff;
      --text: #0f172a;
      --muted: #475569;
      --border: #e2e8f0;
      --accent: #2563eb;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      line-height: 1.7;
      padding: 18px 16px 28px;
      word-break: break-word;
    }
    img, iframe, video {
      max-width: 100%;
      height: auto;
      border-radius: 16px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      display: block;
      overflow-x: auto;
    }
    table td, table th {
      border: 1px solid var(--border);
      padding: 8px 10px;
    }
    a {
      color: var(--accent);
    }
    .hero-image {
      width: 100%;
      margin-bottom: 18px;
      object-fit: cover;
    }
  </style>
</head>
<body>
  $imageMarkup
  $content
</body>
</html>
''';
}
