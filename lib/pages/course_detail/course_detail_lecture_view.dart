import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:docx_viewer/docx_viewer.dart';
import 'package:edupen/core/config/api_config.dart';
import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_constants.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/course_detail/course_detail_repository.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_view.dart';
import 'package:edupen/services/auth_repository.dart';
import 'package:edupen/widgets/learning_dock_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CourseDetailLectureView extends StatefulWidget {
  const CourseDetailLectureView({
    super.key,
    required this.initialItem,
    required this.courseSlug,
    required this.courseTitle,
    required this.sections,
    this.currentDockTab = LearningDockTab.home,
  });

  final CourseDetailLearningItem initialItem;
  final String courseSlug;
  final String courseTitle;
  final List<CourseDetailSection> sections;
  final LearningDockTab currentDockTab;

  @override
  State<CourseDetailLectureView> createState() =>
      _CourseDetailLectureViewState();
}

class _CourseDetailLectureViewState extends State<CourseDetailLectureView>
    with WidgetsBindingObserver {
  static const Duration _progressSaveInterval = Duration(seconds: 30);
  static const double _completionThreshold = 0.9;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CourseDetailRepository _repository = CourseDetailRepository.instance;

  late CourseDetailLearningItem _currentItem;
  late Set<String> _expandedSectionIds;
  VideoPlayerController? _videoController;

  Object? _videoError;
  Timer? _playbackObserver;
  bool _hasHandledVideoEnd = false;
  bool _isCompletingLecture = false;
  DateTime? _lastProgressSaveAt;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _isVideoReady = false;
  bool _isVideoPlaying = false;
  bool _isVideoBuffering = false;
  double _videoAspectRatio = 16 / 9;

  WebViewController? _webViewController;
  bool _isWebLoading = true;
  String? _webError;
  String? _pdfError;
  PdfControllerPinch? _pdfController;
  String? _pdfSourceKey;
  Future<Uint8List>? _docBytesFuture;
  String? _docSourceKey;
  String? _docError;

  CourseDetailResolvedContent? _resolvedContent;
  String? _contentError;
  bool _isLoadingContent = true;
  int _loadGeneration = 0;

  Map<String, CourseLectureProgressStatus> _lectureProgressById =
      <String, CourseLectureProgressStatus>{};
  CourseLectureProgressStatus _currentProgress =
      CourseLectureProgressStatus.empty;

  String? _activeSubtitleSelectionKey;
  final Map<String, String> _subtitleTextCache = <String, String>{};
  String? _subtitleError;

  bool _resumePromptVisible = false;
  bool _completedPromptVisible = false;
  int _resumeSeconds = 0;
  final bool _isVideoDarkMode = false;
  bool _videoControlsVisible = true;
  bool _isVideoFullscreen = false;
  Timer? _videoControlsHideTimer;

  bool get _hasAuthSession {
    final token = AuthRepository.instance.currentToken;
    return token != null && token.trim().isNotEmpty;
  }

  List<CourseDetailLearningItem> get _orderedLectureItems {
    return widget.sections
        .expand((section) => section.items)
        .where((item) => item.isLecture)
        .toList();
  }

  int get _currentLectureIndex {
    return _orderedLectureItems.indexWhere(
      (item) => item.id == _currentItem.id,
    );
  }

  CourseDetailLearningItem? get _previousLecture {
    final index = _currentLectureIndex;
    if (index <= 0) {
      return null;
    }
    return _orderedLectureItems[index - 1];
  }

  CourseDetailLearningItem? get _nextLecture {
    final index = _currentLectureIndex;
    if (index < 0 || index >= _orderedLectureItems.length - 1) {
      return null;
    }
    return _orderedLectureItems[index + 1];
  }

  List<CourseDetailSubtitleTrack> get _subtitleTracks {
    final resolvedTracks = _resolvedContent?.subtitleTracks ?? const [];
    if (resolvedTracks.isNotEmpty) {
      return resolvedTracks;
    }
    return _currentItem.subtitleTracks;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentItem = widget.initialItem;
    _expandedSectionIds = <String>{_currentItem.sectionId};
    unawaited(_applyOrientationForCurrentItem());
    unawaited(_loadBulkLectureProgress());
    unawaited(_loadCurrentItem());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final controller = _videoController;
      if (controller != null && controller.value.isPlaying) {
        controller.pause();
      }
      unawaited(_persistLectureProgress(force: true));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPlaybackObserver();
    _cancelVideoControlsHideTimer();
    unawaited(_persistLectureProgress(force: true));
    unawaited(_unlockPortraitOrientation());
    _videoController?.removeListener(_handleVideoValueChanged);
    _videoController?.dispose();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _lockLandscapeOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _unlockPortraitOrientation() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  bool _shouldUseLandscapeOrientation({CourseDetailResolvedContent? content}) {
    final target = content ?? _resolvedContent;
    if (_currentItem.prefersLandscapeViewer) {
      return true;
    }
    final hasDocumentSource =
        (_currentItem.mediaDocumentUrl?.trim().isNotEmpty ?? false) ||
        (_currentItem.mediaPptxUrl?.trim().isNotEmpty ?? false);
    if (_currentItem.isLecture && hasDocumentSource) {
      return true;
    }
    if (target == null) {
      return false;
    }
    return target.isVideo || _looksLikeDocumentContent(target);
  }

  bool _looksLikePdfContent(CourseDetailResolvedContent? content) {
    if (content == null) {
      return false;
    }
    return content.kind == 'pdf' || _uriHasAnyExtension(content.uri, ['.pdf']);
  }

  bool _looksLikeDocContent(CourseDetailResolvedContent? content) {
    if (content == null) {
      return false;
    }
    return content.kind == 'doc' ||
        _uriHasAnyExtension(content.uri, const ['.doc', '.docx']);
  }

  bool _looksLikePptContent(CourseDetailResolvedContent? content) {
    if (content == null) {
      return false;
    }
    return content.kind == 'ppt' ||
        _uriHasAnyExtension(content.uri, const ['.ppt', '.pptx']);
  }

  bool _looksLikeImageContent(CourseDetailResolvedContent? content) {
    if (content == null) {
      return false;
    }
    return content.kind == 'image' ||
        _uriHasAnyExtension(content.uri, const [
          '.png',
          '.jpg',
          '.jpeg',
          '.gif',
          '.webp',
          '.bmp',
          '.svg',
        ]);
  }

  bool _shouldUseWebViewContent(CourseDetailResolvedContent? content) {
    if (content == null || content.isVideo) {
      return false;
    }
    if (_looksLikePdfContent(content) || _looksLikeDocContent(content)) {
      return false;
    }
    return _looksLikePptContent(content) ||
        _looksLikeImageContent(content) ||
        content.kind == 'web';
  }

  bool _looksLikeDocumentContent(CourseDetailResolvedContent? content) {
    if (content == null) {
      return false;
    }
    if (content.kind == 'pdf' ||
        content.kind == 'doc' ||
        content.kind == 'image' ||
        content.kind == 'ppt') {
      return true;
    }
    return _uriHasAnyExtension(content.uri, const [
      '.pdf',
      '.doc',
      '.docx',
      '.ppt',
      '.pptx',
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
    ]);
  }

  bool _uriHasAnyExtension(Uri uri, List<String> extensions) {
    final path = uri.path.toLowerCase();
    return extensions.any(path.endsWith);
  }

  Future<void> _applyOrientationForCurrentItem({
    CourseDetailResolvedContent? content,
  }) async {
    if (_shouldUseLandscapeOrientation(content: content)) {
      await _lockLandscapeOrientation();
      return;
    }
    await _unlockPortraitOrientation();
  }

  Future<void> _loadBulkLectureProgress() async {
    if (!_hasAuthSession) {
      return;
    }

    final lectureIds = _orderedLectureItems.map((item) => item.id).toList();
    if (lectureIds.isEmpty) {
      return;
    }

    final progress = await _repository.fetchBulkLectureProgress(
      lectureIds: lectureIds,
    );

    if (!mounted || progress.isEmpty) {
      return;
    }

    setState(() {
      _lectureProgressById = progress;
      _currentProgress = _progressForLecture(_currentItem.id);
    });
  }

  Future<void> _loadCurrentItem() async {
    final requestId = ++_loadGeneration;

    await _persistLectureProgress(force: true);
    await _applyOrientationForCurrentItem();
    _resetContentState();

    try {
      final content = await _repository.resolveLectureContent(
        item: _currentItem,
        courseSlug: widget.courseSlug,
      );

      if (!mounted || requestId != _loadGeneration) {
        return;
      }

      _resolvedContent = content;
      await _applyOrientationForCurrentItem(content: content);

      if (content.isVideo) {
        await _initializeVideo(content.uri, requestId);
      } else if (_shouldUseWebViewContent(content)) {
        _initializeWebView(content);
      }

      if (!mounted || requestId != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingContent = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoadingContent = false;
        _contentError = _messageFromError(error);
      });
    }
  }

  void _resetContentState() {
    _stopPlaybackObserver();
    _videoController?.removeListener(_handleVideoValueChanged);
    _videoController?.dispose();
    _videoController = null;
    _videoError = null;
    _videoPosition = Duration.zero;
    _videoDuration = Duration.zero;
    _isVideoReady = false;
    _isVideoPlaying = false;
    _isVideoBuffering = false;
    _videoAspectRatio = 16 / 9;
    _webViewController = null;
    _webError = null;
    _isWebLoading = true;
    _pdfError = null;
    _pdfController?.dispose();
    _pdfController = null;
    _pdfSourceKey = null;
    _docBytesFuture = null;
    _docSourceKey = null;
    _docError = null;
    _resolvedContent = null;
    _contentError = null;
    _isLoadingContent = true;
    _currentProgress = _progressForLecture(_currentItem.id);
    _resumePromptVisible = false;
    _completedPromptVisible = false;
    _resumeSeconds = 0;
    _subtitleError = null;
    _hasHandledVideoEnd = false;
    _isCompletingLecture = false;
    _lastProgressSaveAt = null;
    _videoControlsVisible = true;
    _cancelVideoControlsHideTimer();

    final selectionKey = _activeSubtitleSelectionKey;
    if (selectionKey != null &&
        !_subtitleTracks.any(
          (track) => _subtitleSelectionKey(track) == selectionKey,
        )) {
      _activeSubtitleSelectionKey = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeVideo(Uri uri, int requestId) async {
    final controller = VideoPlayerController.networkUrl(uri);

    try {
      await controller.initialize();

      if (!mounted || requestId != _loadGeneration) {
        controller.dispose();
        return;
      }

      controller.addListener(_handleVideoValueChanged);
      _videoController = controller;

      setState(() {
        _isVideoReady = true;
        _videoError = null;
      });
      _scheduleVideoControlsAutoHide();

      _currentProgress = await _loadProgressForCurrentLecture();
      await _applySelectedSubtitleTrack();
      _startPlaybackObserver();

      if (!mounted || requestId != _loadGeneration) {
        return;
      }

      if (_currentProgress.isCompleted) {
        setState(() {
          _completedPromptVisible = true;
        });
        return;
      }

      if (_currentProgress.watchedSeconds > 0) {
        setState(() {
          _resumeSeconds = _currentProgress.watchedSeconds;
          _resumePromptVisible = true;
        });
        return;
      }

      unawaited(controller.play());
    } catch (error) {
      if (!mounted || requestId != _loadGeneration) {
        return;
      }
      controller.dispose();
      debugPrint('Lecture video open failed: error=$error');
      setState(() {
        _videoError = error;
      });
    }
  }

  void _handleVideoValueChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final value = controller.value;
    final duration = value.duration;
    final aspectRatio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;

    if (mounted) {
      setState(() {
        _videoPosition = value.position;
        _videoDuration = duration;
        _isVideoReady = true;
        _isVideoPlaying = value.isPlaying;
        _isVideoBuffering = value.isBuffering;
        _videoAspectRatio = aspectRatio;
      });
    }

    if (value.isPlaying) {
      _scheduleVideoControlsAutoHide();
    } else {
      _cancelVideoControlsHideTimer();
      if (mounted && !_videoControlsVisible) {
        setState(() {
          _videoControlsVisible = true;
        });
      }
    }

    if (duration <= Duration.zero) {
      return;
    }

    final hasEnded =
        value.position >= duration - const Duration(milliseconds: 300);
    if (hasEnded && !_hasHandledVideoEnd) {
      _hasHandledVideoEnd = true;
      unawaited(_persistLectureProgress(force: true));
    } else if (!hasEnded) {
      _hasHandledVideoEnd = false;
    }
  }

  Future<CourseLectureProgressStatus> _loadProgressForCurrentLecture() async {
    if (!_currentItem.isLecture || !_hasAuthSession) {
      return CourseLectureProgressStatus.empty;
    }

    final existing = _lectureProgressById[_currentItem.id];
    if (existing != null) {
      return existing;
    }

    final progress = await _repository.fetchLectureProgress(
      lectureId: _currentItem.id,
    );

    if (!mounted) {
      return progress;
    }

    setState(() {
      _lectureProgressById = <String, CourseLectureProgressStatus>{
        ..._lectureProgressById,
        _currentItem.id: progress,
      };
    });

    return progress;
  }

  void _initializeWebView(CourseDetailResolvedContent content) {
    final targetUri = _webViewTargetUri(content);
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
                  ? _sanitizeUserError(error.description)
                  : 'Không tải được nội dung.';
            });
          },
        ),
      )
      ..loadRequest(targetUri);

    _webViewController = controller;
  }

  Uri _webViewTargetUri(CourseDetailResolvedContent content) {
    if (_looksLikePptContent(content)) {
      return Uri.https('view.officeapps.live.com', '/op/embed.aspx', {
        'src': content.uri.toString(),
      });
    }
    return content.uri;
  }

  void _startPlaybackObserver() {
    _stopPlaybackObserver();
    _playbackObserver = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _handlePlaybackTick(),
    );
  }

  void _stopPlaybackObserver() {
    _playbackObserver?.cancel();
    _playbackObserver = null;
  }

  Future<void> _handlePlaybackTick() async {
    final content = _resolvedContent;
    if (!_isVideoReady || content == null || !content.isVideo) {
      return;
    }

    final duration = _videoDuration;
    if (duration <= Duration.zero) {
      return;
    }

    if (!_currentProgress.isCompleted &&
        !_isCompletingLecture &&
        _videoPosition.inMilliseconds >=
            (duration.inMilliseconds * _completionThreshold).round()) {
      _isCompletingLecture = true;
      final watchedSeconds = _videoPosition.inSeconds;
      final completed = await _repository.completeLecture(
        lectureId: _currentItem.id,
        watchedSeconds: watchedSeconds,
      );
      if (completed && mounted) {
        _updateLectureProgress(
          _currentItem.id,
          _progressForLecture(
            _currentItem.id,
          ).copyWith(isCompleted: true, watchedSeconds: watchedSeconds),
        );
      }
      _isCompletingLecture = false;
    }

    if (!_isVideoPlaying || !_hasAuthSession) {
      return;
    }

    final now = DateTime.now();
    if (_lastProgressSaveAt == null ||
        now.difference(_lastProgressSaveAt!) >= _progressSaveInterval) {
      await _persistLectureProgress();
    }
  }

  Future<void> _persistLectureProgress({bool force = false}) async {
    final content = _resolvedContent;
    if (!_hasAuthSession ||
        !_isVideoReady ||
        content == null ||
        !content.isVideo ||
        _currentProgress.isCompleted) {
      return;
    }

    final watchedSeconds = _videoPosition.inSeconds;
    final previous = _progressForLecture(_currentItem.id).watchedSeconds;
    if (!force && watchedSeconds <= previous) {
      return;
    }

    _lastProgressSaveAt = DateTime.now();
    await _repository.updateLectureProgress(
      lectureId: _currentItem.id,
      watchedSeconds: watchedSeconds,
    );

    if (!mounted) {
      return;
    }

    _updateLectureProgress(
      _currentItem.id,
      _progressForLecture(
        _currentItem.id,
      ).copyWith(watchedSeconds: watchedSeconds),
    );
  }

  CourseLectureProgressStatus _progressForLecture(String lectureId) {
    return _lectureProgressById[lectureId] ?? CourseLectureProgressStatus.empty;
  }

  void _updateLectureProgress(
    String lectureId,
    CourseLectureProgressStatus progress,
  ) {
    setState(() {
      _lectureProgressById = <String, CourseLectureProgressStatus>{
        ..._lectureProgressById,
        lectureId: progress,
      };
      if (_currentItem.id == lectureId) {
        _currentProgress = progress;
      }
    });
  }

  Future<void> _applySelectedSubtitleTrack() async {
    final content = _resolvedContent;
    if (content == null || !content.isVideo) {
      return;
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final track = _subtitleTracks.firstWhere(
      (candidate) =>
          _subtitleSelectionKey(candidate) == _activeSubtitleSelectionKey,
      orElse: () => const CourseDetailSubtitleTrack(path: ''),
    );

    if (track.path.isEmpty) {
      await controller.setClosedCaptionFile(null);
      if (mounted) {
        setState(() {
          _subtitleError = null;
        });
      }
      return;
    }

    setState(() {
      _subtitleError = null;
    });

    try {
      await controller.setClosedCaptionFile(
        Future<ClosedCaptionFile>.value(await _loadClosedCaptionFile(track)),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _subtitleError = _messageFromError(error);
        });
      }
    }
  }

  Future<ClosedCaptionFile> _loadClosedCaptionFile(
    CourseDetailSubtitleTrack track,
  ) async {
    final cached = _subtitleTextCache[track.path];
    if (cached != null) {
      return track.path.toLowerCase().endsWith('.vtt')
          ? WebVTTCaptionFile(cached)
          : SubRipCaptionFile(cached);
    }

    final raw = await _repository.loadRemoteText(Uri.parse(track.path));
    _subtitleTextCache[track.path] = raw;
    return track.path.toLowerCase().endsWith('.vtt')
        ? WebVTTCaptionFile(raw)
        : SubRipCaptionFile(raw);
  }

  String _subtitleSelectionKey(CourseDetailSubtitleTrack track) {
    final language = track.normalizedLanguage;
    return language.isNotEmpty ? language : track.path;
  }

  void _toggleSubtitle(CourseDetailSubtitleTrack track) {
    final nextKey = _subtitleSelectionKey(track);
    setState(() {
      _activeSubtitleSelectionKey = _activeSubtitleSelectionKey == nextKey
          ? null
          : nextKey;
    });
    unawaited(_applySelectedSubtitleTrack());
  }

  Future<void> _resumeFromStart() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.seekTo(Duration.zero);
    if (_hasAuthSession) {
      await _repository.updateLectureProgress(
        lectureId: _currentItem.id,
        watchedSeconds: 0,
      );
      if (mounted) {
        _updateLectureProgress(
          _currentItem.id,
          _progressForLecture(_currentItem.id).copyWith(watchedSeconds: 0),
        );
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _resumePromptVisible = false;
      _completedPromptVisible = false;
    });
    await controller.play();
  }

  Future<void> _resumeFromLastPosition() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final maxSeconds = controller.value.duration.inSeconds;
    final safeSeconds = _resumeSeconds >= maxSeconds && maxSeconds > 1
        ? maxSeconds - 1
        : _resumeSeconds;
    final targetSeconds = safeSeconds.clamp(0, maxSeconds);
    await controller.seekTo(Duration(seconds: targetSeconds));
    if (!mounted) {
      return;
    }
    setState(() {
      _resumePromptVisible = false;
    });
    await controller.play();
  }

  Future<void> _replayCompletedLecture() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await controller.seekTo(Duration.zero);
    if (!mounted) {
      return;
    }
    setState(() {
      _completedPromptVisible = false;
    });
    await controller.play();
  }

  int _completedLectureCountForSection(CourseDetailSection section) {
    return section.items
        .where((item) => item.isLecture)
        .where((item) => _progressForLecture(item.id).isCompleted)
        .length;
  }

  int _lectureCountForSection(CourseDetailSection section) {
    return section.items.where((item) => item.isLecture).length;
  }

  Future<void> _openLearningItem(CourseDetailLearningItem item) async {
    if (item.id == _currentItem.id && item.isLecture) {
      return;
    }

    if (item.isDraft) {
      _showSnackBar('Nội dung này đang ở trạng thái nháp.');
      return;
    }

    if (!item.canOpen) {
      _showSnackBar('Bạn chưa có quyền truy cập nội dung này.');
      return;
    }

    if (item.isQuiz) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => QuizDetailView(
            quizId: item.id,
            currentTab: widget.currentDockTab,
          ),
        ),
      );
      return;
    }

    if (!item.isLecture) {
      _showSnackBar('Nội dung này chưa hỗ trợ trên mobile app.');
      return;
    }

    setState(() {
      _currentItem = item;
      _expandedSectionIds = <String>{item.sectionId};
    });
    await _loadCurrentItem();
  }

  void _toggleSection(String sectionId) {
    setState(() {
      if (_expandedSectionIds.contains(sectionId)) {
        _expandedSectionIds.remove(sectionId);
      } else {
        _expandedSectionIds.add(sectionId);
      }
    });
  }

  void _toggleVideoPlayback() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
      unawaited(_persistLectureProgress(force: true));
    } else if (!_resumePromptVisible && !_completedPromptVisible) {
      unawaited(controller.play());
    }
    setState(() {});
  }

  void _toggleVideoControlsVisibility() {
    setState(() {
      _videoControlsVisible = !_videoControlsVisible;
    });

    if (_videoControlsVisible) {
      _scheduleVideoControlsAutoHide();
    } else {
      _cancelVideoControlsHideTimer();
    }
  }

  void _cancelVideoControlsHideTimer() {
    _videoControlsHideTimer?.cancel();
    _videoControlsHideTimer = null;
  }

  void _scheduleVideoControlsAutoHide() {
    _cancelVideoControlsHideTimer();
    final controller = _videoController;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying ||
        _resumePromptVisible ||
        _completedPromptVisible) {
      return;
    }

    _videoControlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _videoControlsVisible = false;
      });
    });
  }

  Future<void> _toggleVideoFullscreen() async {
    final nextValue = !_isVideoFullscreen;
    if (mounted) {
      setState(() {
        _isVideoFullscreen = nextValue;
        _videoControlsVisible = true;
      });
    }

    if (nextValue) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _scheduleVideoControlsAutoHide();
  }

  void _openCurriculum() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFromError(Object error) {
    if (error is String) {
      return _sanitizeUserError(error);
    }
    if (error is AppException) {
      return _sanitizeUserError(error.message);
    }
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        final message = responseData['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _sanitizeUserError(message);
        }
      }
      if (responseData is List<int> && responseData.isNotEmpty) {
        final decoded = String.fromCharCodes(responseData).trim();
        if (decoded.isNotEmpty && decoded.length < 300) {
          return _sanitizeUserError(decoded);
        }
      }
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        return 'Máy chủ trả về lỗi $statusCode khi tải tài liệu.';
      }
      final message = error.message ?? 'Không tải được dữ liệu.';
      return _sanitizeUserError(message);
    }
    final fallback = error.toString().trim();
    if (fallback.isNotEmpty && fallback != 'null') {
      return _sanitizeUserError(fallback);
    }
    return 'Không tải được nội dung bài học.';
  }

  String _videoErrorMessage() {
    final error = _videoError;
    if (error == null) {
      return 'Không phát được video trực tiếp trên app.';
    }

    final detail = _messageFromError(error);
    return 'Không phát được video trực tiếp trên app.\n$detail';
  }

  String _sanitizeUserError(String message) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Có lỗi xảy ra.';
    }

    final withoutUrls = trimmed.replaceAll(
      RegExp(r'https?:\/\/[^\s]+', caseSensitive: false),
      '[ẩn liên kết]',
    );
    return withoutUrls;
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        _isVideoDarkMode && _resolvedContent?.isVideo == true
        ? const Color(0xFF04070D)
        : CourseDetailPalette.background;
    final isVideoScreen = _resolvedContent?.isVideo == true;
    final hideAppBar = isVideoScreen && _isVideoFullscreen;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      endDrawer: _LectureCurriculumDrawer(
        courseTitle: widget.courseTitle,
        currentItem: _currentItem,
        sections: widget.sections,
        expandedSectionIds: _expandedSectionIds,
        completedCountBuilder: _completedLectureCountForSection,
        lectureCountBuilder: _lectureCountForSection,
        progressForLecture: _progressForLecture,
        onToggleSection: _toggleSection,
        onItemTap: _openLearningItem,
      ),
      appBar: hideAppBar
          ? null
          : AppBar(
              toolbarHeight: isVideoScreen ? 52 : kToolbarHeight,
              backgroundColor: _isVideoDarkMode && isVideoScreen
                  ? const Color(0xFF0B1120)
                  : Colors.white,
              surfaceTintColor: Colors.transparent,
              foregroundColor: _isVideoDarkMode && isVideoScreen
                  ? Colors.white
                  : CourseDetailPalette.textPrimary,
              titleSpacing: 0,
              title: Text(
                _currentItem.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isVideoScreen ? 18 : 20,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Bài trước',
                  visualDensity: isVideoScreen
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  onPressed: _previousLecture == null
                      ? null
                      : () => unawaited(_openLearningItem(_previousLecture!)),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: 'Bài tiếp',
                  visualDensity: isVideoScreen
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  onPressed: _nextLecture == null
                      ? null
                      : () => unawaited(_openLearningItem(_nextLecture!)),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                IconButton(
                  tooltip: 'Chương trình giảng dạy',
                  visualDensity: isVideoScreen
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  onPressed: _openCurriculum,
                  icon: const Icon(Icons.view_sidebar_rounded),
                ),
              ],
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingContent) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contentError != null) {
      return _ErrorState(message: _contentError!, onRetry: _loadCurrentItem);
    }

    final content = _resolvedContent;
    if (content == null) {
      return _ErrorState(
        message: 'Không tìm thấy nội dung bài học.',
        onRetry: _loadCurrentItem,
      );
    }

    if (content.isVideo) {
      return _buildVideoViewport();
    }

    if (_looksLikePdfContent(content)) {
      if (_pdfError != null) {
        return _ErrorState(
          message: 'Không mở được tài liệu PDF.\n$_pdfError',
          onRetry: _loadCurrentItem,
          retryLabel: 'Tải lại',
        );
      }
      return _buildPdfViewport(content);
    }

    if (_looksLikeDocContent(content)) {
      if (_docError != null) {
        return _ErrorState(
          message: 'Không mở được tài liệu Word.\n$_docError',
          onRetry: _loadCurrentItem,
          retryLabel: 'Tải lại',
        );
      }
      return _buildDocViewport(content);
    }

    return _buildWebViewport();
  }

  Widget _buildVideoViewport() {
    if (_videoError != null) {
      return _ErrorState(
        message: _videoErrorMessage(),
        onRetry: _loadCurrentItem,
        retryLabel: 'Tải lại',
      );
    }

    if (!_isVideoReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final duration = _videoDuration;
    final rawPosition = _videoPosition;
    final position = rawPosition > duration && duration > Duration.zero
        ? duration
        : rawPosition;
    final sliderMax = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = position.inMilliseconds.clamp(0, sliderMax.toInt());

    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleVideoControlsVisibility,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _videoAspectRatio > 0 ? _videoAspectRatio : 16 / 9,
                child: VideoPlayer(_videoController!),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  _videoControlsVisible ? 88 : 18,
                ),
                child: IgnorePointer(
                  child: ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _videoController!,
                    builder: (context, value, _) {
                      final captionText = value.caption.text.trim();
                      if (captionText.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            captionText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_isVideoBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_videoControlsVisible &&
                !_resumePromptVisible &&
                !_completedPromptVisible)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.16),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.42),
                        ],
                        stops: const [0, 0.52, 1],
                      ),
                    ),
                    child: Column(
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            child: Row(
                              children: [
                                if (_isVideoFullscreen)
                                  IconButton(
                                    onPressed: () =>
                                        unawaited(_toggleVideoFullscreen()),
                                    color: Colors.white,
                                    icon: const Icon(
                                      Icons.fullscreen_exit_rounded,
                                    ),
                                  ),
                                const Spacer(),
                                if (_subtitleTracks.isNotEmpty)
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: [
                                      for (final track in _subtitleTracks)
                                        GestureDetector(
                                          onTap: () => _toggleSubtitle(track),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 6,
                                            ),
                                            child: Text(
                                              _activeSubtitleSelectionKey ==
                                                      _subtitleSelectionKey(
                                                        track,
                                                      )
                                                  ? '${track.shortLabel} ON'
                                                  : 'Sub ${track.shortLabel}',
                                              style: TextStyle(
                                                color:
                                                    _activeSubtitleSelectionKey ==
                                                        _subtitleSelectionKey(
                                                          track,
                                                        )
                                                    ? const Color(0xFFA5B4FC)
                                                    : Colors.white70,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                letterSpacing: 0.2,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black87,
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_subtitleError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F1D1D),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _subtitleError!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        const Spacer(),
                        IconButton.filled(
                          onPressed: _toggleVideoPlayback,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.42,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          iconSize: 34,
                          icon: Icon(
                            _isVideoPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                        const Spacer(),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      overlayShape:
                                          SliderComponentShape.noOverlay,
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                    ),
                                    child: Slider(
                                      value: sliderValue.toDouble(),
                                      min: 0,
                                      max: sliderMax,
                                      onChanged: (value) {
                                        setState(() {
                                          _videoPosition = Duration(
                                            milliseconds: value.round(),
                                          );
                                        });
                                      },
                                      onChangeEnd: (value) => unawaited(
                                        _videoController!.seekTo(
                                          Duration(milliseconds: value.round()),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () =>
                                      unawaited(_toggleVideoFullscreen()),
                                  color: Colors.white,
                                  icon: Icon(
                                    _isVideoFullscreen
                                        ? Icons.fullscreen_exit_rounded
                                        : Icons.fullscreen_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_resumePromptVisible)
              _buildVideoPrompt(
                title: 'Tiếp tục xem?',
                message:
                    'Lần trước bạn đang xem tới ${_formatDuration(Duration(seconds: _resumeSeconds))}.',
                secondaryLabel: 'Xem từ đầu',
                primaryLabel: 'Xem tiếp',
                onSecondaryTap: _resumeFromStart,
                onPrimaryTap: _resumeFromLastPosition,
              ),
            if (_completedPromptVisible)
              _buildVideoPrompt(
                title: 'Bạn đã hoàn thành video',
                message: 'Bạn có muốn xem lại từ đầu không?',
                secondaryLabel: 'Để sau',
                primaryLabel: 'Xem lại',
                onSecondaryTap: () async {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _completedPromptVisible = false;
                  });
                },
                onPrimaryTap: _replayCompletedLecture,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPrompt({
    required String title,
    required String message,
    required String secondaryLabel,
    required String primaryLabel,
    required Future<void> Function() onSecondaryTap,
    required Future<void> Function() onPrimaryTap,
  }) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF11172B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD5D9E7),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => unawaited(onSecondaryTap()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF44506B)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(secondaryLabel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => unawaited(onPrimaryTap()),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebViewport() {
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
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.96),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ErrorState(
                    message: _webError!,
                    onRetry: () async {
                      setState(() {
                        _webError = null;
                        _isWebLoading = true;
                      });
                      await controller.reload();
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfViewport(CourseDetailResolvedContent content) {
    final sourceKey = content.uri.toString();
    if (_pdfController == null || _pdfSourceKey != sourceKey) {
      _pdfController?.dispose();
      _pdfSourceKey = sourceKey;
      _pdfController = PdfControllerPinch(
        document: _loadPdfDocument(content.uri),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onDocumentError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _pdfError = _messageFromError(error);
        });
      },
    );
  }

  Future<PdfDocument> _loadPdfDocument(Uri uri) async {
    final bytes = await _repository.loadRemoteBytes(
      uri,
      headers: _documentHeaders(),
    );
    return PdfDocument.openData(bytes);
  }

  Widget _buildDocViewport(CourseDetailResolvedContent content) {
    final sourceKey = content.uri.toString();
    if (_docBytesFuture == null || _docSourceKey != sourceKey) {
      _docSourceKey = sourceKey;
      _docBytesFuture = _repository.loadRemoteBytes(
        content.uri,
        headers: _documentHeadersForUri(content.uri),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _docBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final message = _messageFromError(snapshot.error!);
          if (_docError != message) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _docError = message;
              });
            });
          }
          return _ErrorState(
            message: 'Không mở được tài liệu Word.\n$message',
            onRetry: _loadCurrentItem,
            retryLabel: 'Tải lại',
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return _ErrorState(
            message: 'Không tải được dữ liệu tài liệu Word.',
            onRetry: _loadCurrentItem,
            retryLabel: 'Tải lại',
          );
        }

        return DocxView(
          bytes: bytes,
          onError: (error) {
            final message = _messageFromError(error);
            if (!mounted || _docError == message) {
              return;
            }
            setState(() {
              _docError = message;
            });
          },
        );
      },
    );
  }

  Map<String, String> _documentHeaders() {
    return _documentHeadersForUri(_resolvedContent?.uri);
  }

  Map<String, String> _documentHeadersForUri(Uri? uri) {
    final token = AuthRepository.instance.currentToken?.trim();
    final headers = <String, String>{
      'Accept': _acceptHeaderForDocumentUri(uri),
    };
    if (token == null || token.isEmpty || !_shouldAttachDocumentAuth(uri)) {
      return headers;
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  String _acceptHeaderForDocumentUri(Uri? uri) {
    if (uri == null) {
      return 'application/octet-stream, */*';
    }

    final path = uri.path.toLowerCase();
    if (path.endsWith('.pdf') || path.contains('/stream-pdf/')) {
      return 'application/pdf, application/octet-stream, */*';
    }
    if (path.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document, application/octet-stream, */*';
    }
    if (path.endsWith('.doc')) {
      return 'application/msword, application/octet-stream, */*';
    }
    return 'application/octet-stream, */*';
  }

  bool _shouldAttachDocumentAuth(Uri? uri) {
    if (uri == null) {
      return true;
    }

    if (uri.queryParameters.isNotEmpty) {
      return false;
    }

    final webBaseUri = Uri.parse(ApiConfig.webBaseUrl);
    final isSameHost =
        uri.host == webBaseUri.host &&
        (uri.scheme == webBaseUri.scheme || uri.scheme.isEmpty) &&
        (!uri.hasPort || !webBaseUri.hasPort || uri.port == webBaseUri.port);
    if (!isSameHost) {
      return false;
    }

    final path = uri.path.toLowerCase();
    return path.contains('/media/stream-pdf/') ||
        path.contains('/media/stream/');
  }
}

class _LectureCurriculumDrawer extends StatelessWidget {
  const _LectureCurriculumDrawer({
    required this.courseTitle,
    required this.currentItem,
    required this.sections,
    required this.expandedSectionIds,
    required this.completedCountBuilder,
    required this.lectureCountBuilder,
    required this.progressForLecture,
    required this.onToggleSection,
    required this.onItemTap,
  });

  final String courseTitle;
  final CourseDetailLearningItem currentItem;
  final List<CourseDetailSection> sections;
  final Set<String> expandedSectionIds;
  final int Function(CourseDetailSection section) completedCountBuilder;
  final int Function(CourseDetailSection section) lectureCountBuilder;
  final CourseLectureProgressStatus Function(String lectureId)
  progressForLecture;
  final ValueChanged<String> onToggleSection;
  final Future<void> Function(CourseDetailLearningItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = math.min(
      math.max(screenWidth * 0.46, 360.0),
      screenWidth - 32,
    );

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Khóa học',
                          style: TextStyle(
                            color: CourseDetailPalette.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          courseTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CourseDetailPalette.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                children: [
                  const Text(
                    'Chương trình giảng dạy',
                    style: TextStyle(
                      color: CourseDetailPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(sections.length, (index) {
                    final section = sections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LectureSectionTile(
                        index: index + 1,
                        section: section,
                        currentItemId: currentItem.id,
                        isExpanded: expandedSectionIds.contains(section.id),
                        completedCount: completedCountBuilder(section),
                        lectureCount: lectureCountBuilder(section),
                        progressForLecture: progressForLecture,
                        onToggle: () => onToggleSection(section.id),
                        onItemTap: onItemTap,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LectureSectionTile extends StatelessWidget {
  const _LectureSectionTile({
    required this.index,
    required this.section,
    required this.currentItemId,
    required this.isExpanded,
    required this.completedCount,
    required this.lectureCount,
    required this.progressForLecture,
    required this.onToggle,
    required this.onItemTap,
  });

  final int index;
  final CourseDetailSection section;
  final String currentItemId;
  final bool isExpanded;
  final int completedCount;
  final int lectureCount;
  final CourseLectureProgressStatus Function(String lectureId)
  progressForLecture;
  final VoidCallback onToggle;
  final Future<void> Function(CourseDetailLearningItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final progress = lectureCount == 0 ? 0.0 : completedCount / lectureCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CourseDetailPalette.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: CourseDetailPalette.info,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          section.title,
                          style: const TextStyle(
                            color: CourseDetailPalette.textPrimary,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: CourseDetailPalette.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$completedCount/$lectureCount bài học',
                    style: const TextStyle(
                      color: CourseDetailPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE5E7EB),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ...section.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _LectureItemTile(
                        item: item,
                        isActive: item.id == currentItemId,
                        progress: item.isLecture
                            ? progressForLecture(item.id)
                            : CourseLectureProgressStatus.empty,
                        onTap: () {
                          Navigator.of(context).pop();
                          unawaited(onItemTap(item));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LectureItemTile extends StatelessWidget {
  const _LectureItemTile({
    required this.item,
    required this.isActive,
    required this.progress,
    required this.onTap,
  });

  final CourseDetailLearningItem item;
  final bool isActive;
  final CourseLectureProgressStatus progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.isLecture && progress.isCompleted;

    return Material(
      color: isActive
          ? const Color(0xFFEAF2FF)
          : isCompleted
          ? const Color(0xFFECFDF5)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _resolveLearningIcon(item),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CourseDetailPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.badgeLabel ?? item.metaLabel ?? item.typeLabel,
                      style: const TextStyle(
                        color: CourseDetailPalette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF059669))
              else if (item.isLocked)
                const Icon(
                  Icons.lock_outline_rounded,
                  color: CourseDetailPalette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveLearningIcon(CourseDetailLearningItem item) {
    if (item.isQuiz) {
      return Icons.quiz_rounded;
    }
    if (item.isVideoLike) {
      return Icons.ondemand_video_rounded;
    }
    if (item.isPdfLike) {
      return Icons.picture_as_pdf_rounded;
    }
    if (item.isDocLike) {
      return Icons.description_rounded;
    }
    if (item.isImageLike) {
      return Icons.image_rounded;
    }
    if (item.isPptLike) {
      return Icons.slideshow_rounded;
    }
    return Icons.play_lesson_rounded;
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Thử lại',
  });

  final String message;
  final Future<void> Function() onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.redAccent,
                    size: 36,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CourseDetailPalette.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => unawaited(onRetry()),
                    child: Text(retryLabel),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
