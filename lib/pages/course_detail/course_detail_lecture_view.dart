import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/course_detail/course_detail_constants.dart';
import 'package:edly/pages/course_detail/course_detail_models.dart';
import 'package:edly/pages/course_detail/course_detail_repository.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CourseDetailLectureView extends StatefulWidget {
  const CourseDetailLectureView({
    super.key,
    required this.item,
    required this.courseSlug,
  });

  final CourseDetailLearningItem item;
  final String courseSlug;

  @override
  State<CourseDetailLectureView> createState() =>
      _CourseDetailLectureViewState();
}

class _CourseDetailLectureViewState extends State<CourseDetailLectureView>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  Object? _videoError;

  WebViewController? _webViewController;
  bool _isWebLoading = true;
  String? _webError;

  CourseDetailResolvedContent? _resolvedContent;
  late Future<CourseDetailResolvedContent> _contentFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _contentFuture = _loadContent();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _videoController;
    if (controller == null || _resolvedContent?.isVideo != true) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    super.dispose();
  }

  Future<CourseDetailResolvedContent> _loadContent() async {
    final content = await CourseDetailRepository.instance.resolveLectureContent(
      item: widget.item,
      courseSlug: widget.courseSlug,
    );

    _resolvedContent = content;
    _videoError = null;

    if (content.isVideo) {
      await _initializeVideo(content.uri);
    } else {
      _initializeWebView(content.uri);
    }

    return content;
  }

  Future<void> _initializeVideo(Uri uri) async {
    _videoController?.dispose();
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {'Accept': 'application/json'},
    );
    _videoController = controller;

    try {
      await controller.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _videoError = error;
      });
    }
  }

  void _initializeWebView(Uri uri) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isWebLoading = true;
              _webError = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isWebLoading = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isWebLoading = false;
              _webError = error.description.isNotEmpty
                  ? error.description
                  : 'Không tải được nội dung.';
            });
          },
        ),
      )
      ..loadRequest(uri, headers: const {'Accept': 'application/json'});

    _webViewController = controller;
  }

  Future<void> _retryContent() async {
    setState(() {
      _resolvedContent = null;
      _videoError = null;
      _webError = null;
      _isWebLoading = true;
      _webViewController = null;
      _contentFuture = _loadContent();
    });
  }

  void _openFallbackPage(CourseDetailResolvedContent content) {
    final fallback = content.fallbackPageUri;
    if (fallback == null) {
      _retryContent();
      return;
    }

    _resolvedContent = CourseDetailResolvedContent(
      uri: fallback,
      kind: 'web',
      fallbackPageUri: fallback,
    );
    _videoError = null;
    _initializeWebView(fallback);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CourseDetailPalette.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          widget.item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: CourseDetailPalette.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<CourseDetailResolvedContent>(
      future: _contentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _ErrorState(
            message: error is AppException
                ? error.message
                : 'Không tải được nội dung bài học.',
            onRetry: _retryContent,
          );
        }

        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final content = snapshot.data!;
        if (content.isVideo) {
          return _buildVideoBody(content);
        }
        return _buildWebBody();
      },
    );
  }

  Widget _buildVideoBody(CourseDetailResolvedContent content) {
    if (_videoError != null) {
      return _ErrorState(
        message:
            'Không phát được video trực tiếp. Mở nội dung trong app để tiếp tục.',
        onRetry: () => _openFallbackPage(content),
        retryLabel: 'Mở nội dung',
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final aspectRatio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio
        : 16 / 9;

    return Column(
      children: [
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(color: Colors.black, child: VideoPlayer(controller)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                  setState(() {});
                },
                icon: Icon(
                  controller.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 32,
                  color: CourseDetailPalette.textPrimary,
                ),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: const VideoProgressColors(
                    playedColor: CourseDetailPalette.info,
                    bufferedColor: Color(0xFFBFDBFE),
                    backgroundColor: Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWebBody() {
    final controller = _webViewController;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (_isWebLoading) const LinearProgressIndicator(minHeight: 2),
        if (_webError != null)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.95),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: _ErrorState(
                message: _webError!,
                onRetry: () {
                  setState(() {
                    _webError = null;
                    _isWebLoading = true;
                  });
                  controller.reload();
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry, this.retryLabel});

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 34,
              color: CourseDetailPalette.warning,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CourseDetailPalette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: Text(retryLabel ?? 'Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
