import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_controller.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edly/pages/quiz_detail/quiz_room_view.dart';
import 'package:edly/services/auth_repository.dart';
import 'package:edly/widgets/mobile_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QuizDetailView extends StatefulWidget {
  const QuizDetailView({super.key, required this.quizId});

  final String quizId;

  @override
  State<QuizDetailView> createState() => _QuizDetailViewState();
}

class _QuizDetailViewState extends State<QuizDetailView> {
  late final QuizDetailController _controller;
  bool _isOpeningRoom = false;

  @override
  void initState() {
    super.initState();
    _controller = QuizDetailController();
    _controller.load(widget.quizId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openQuizRoom() async {
    if (_isOpeningRoom) {
      return;
    }

    setState(() {
      _isOpeningRoom = true;
    });

    try {
      final room = await QuizDetailRepository.instance.fetchQuizRoom(
        widget.quizId,
      );

      if (!mounted) {
        return;
      }

      final changed = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => QuizRoomView(room: room)));

      if (changed == true) {
        await _controller.load(widget.quizId);
      }
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
          _isOpeningRoom = false;
        });
      }
    }
  }

  Future<void> _purchaseQuiz(QuizDetailData data) async {
    final courseId = data.course?.id;
    if (courseId == null || courseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không xác định được khóa học của đề thi.'),
        ),
      );
      return;
    }

    final result = await showContentPaymentSheet(
      context: context,
      title: data.quiz.name,
      amount: data.quiz.price,
      contentType: 'quiz',
      contentId: data.quiz.id,
      courseId: courseId,
      onBalancePurchase: () async {
        final result = await _controller.purchaseByBalance(
          quizId: data.quiz.id,
          courseId: courseId,
        );
        if (result == null) {
          throw AppException(
            _controller.errorMessage ??
                'Không thể mua quyền vào phòng thi lúc này.',
          );
        }
        return result;
      },
    );

    if (!mounted || result?.completed != true) {
      return;
    }

    await AuthRepository.instance.refreshCurrentUser();
    await _controller.load(widget.quizId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result!.message)));
  }

  void _downloadQuiz(QuizDetailData data) {
    if (!data.access.canAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần mua đề thi để tải xuống.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng tải xuống đang được đồng bộ từ web backend.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final data = _controller.data;

        return Scaffold(
          backgroundColor: QuizDetailPalette.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text(
              'Chi tiết đề thi',
              style: TextStyle(
                color: QuizDetailPalette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          body: _controller.isLoading && data == null
              ? const Center(child: CircularProgressIndicator())
              : data == null
              ? _ErrorState(
                  message:
                      _controller.errorMessage ??
                      'Không tải được dữ liệu đề thi.',
                  onRetry: () => _controller.load(widget.quizId),
                )
              : RefreshIndicator(
                  onRefresh: () => _controller.load(widget.quizId),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeroSection(
                        data: data,
                        isBusy: _controller.isPurchasing || _isOpeningRoom,
                        onOpenRoom: _openQuizRoom,
                        onPurchase: () => _purchaseQuiz(data),
                        onDownload: () => _downloadQuiz(data),
                      ),
                      const SizedBox(height: 14),
                      _OverviewStats(data: data),
                      const SizedBox(height: 14),
                      _ModuleStructureCard(data: data),
                      const SizedBox(height: 14),
                      _ProgressCard(history: data.history),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.data,
    required this.isBusy,
    required this.onOpenRoom,
    required this.onPurchase,
    required this.onDownload,
  });

  final QuizDetailData data;
  final bool isBusy;
  final Future<void> Function() onOpenRoom;
  final Future<void> Function() onPurchase;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final quiz = data.quiz;
    final hasAccess = data.access.canAccess;
    final timeLabel = _formatTime(_displayMinutes(quiz));
    final dateLabel = quiz.updatedAt == null
        ? '-'
        : DateFormat('dd/MM/yyyy').format(quiz.updatedAt!);
    final statusLabel = hasAccess ? 'Đã mua' : 'Chưa mua';
    final statusColor = hasAccess
        ? const Color(0xFF6EE7B7)
        : const Color(0xFFFDE68A);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF472A3E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quiz.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _MetaText(label: 'Thời gian', value: timeLabel),
              _MetaText(label: 'Cập nhật', value: dateLabel),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Trạng thái: ',
                    style: TextStyle(color: Color(0xFFD7C9D2)),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (hasAccess)
                FilledButton.icon(
                  onPressed: isBusy ? null : onOpenRoom,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    quiz.isExamMode ? 'Bắt đầu thi' : 'Bắt đầu làm bài',
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: isBusy ? null : onPurchase,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                  ),
                  icon: const Icon(Icons.shopping_cart_checkout_rounded),
                  label: const Text('Mua ngay'),
                ),
              if (hasAccess) ...[
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onOpenRoom,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Làm lại từ đầu'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onDownload,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    side: const BorderSide(color: Color(0xFF34D399)),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Tải xuống'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.data});

  final QuizDetailData data;

  @override
  Widget build(BuildContext context) {
    final quiz = data.quiz;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Row(
        children: [
          _OverviewCell(label: 'Câu hỏi', value: '${quiz.questionCount}'),
          _OverviewCell(
            label: 'Thời gian',
            value: _formatTime(_displayMinutes(quiz)),
          ),
          _OverviewCell(
            label: 'Loại',
            value: data.room.isExam ? 'Bài thi' : 'Bài tập',
          ),
          _OverviewCell(label: 'Lượt thi', value: '${data.history.length}'),
        ],
      ),
    );
  }
}

class _OverviewCell extends StatelessWidget {
  const _OverviewCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: QuizDetailPalette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ModuleStructureCard extends StatelessWidget {
  const _ModuleStructureCard({required this.data});

  final QuizDetailData data;

  @override
  Widget build(BuildContext context) {
    final modules = data.quiz.modules;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cấu trúc đề thi',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (modules.isEmpty)
            const Text(
              'Không có dữ liệu module cho đề thi này.',
              style: TextStyle(color: QuizDetailPalette.textSecondary),
            )
          else
            ...modules.map(
              (module) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: QuizDetailPalette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          module.name,
                          style: const TextStyle(
                            color: QuizDetailPalette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (module.defaultQuestionCount > 0)
                        _Tag(
                          text: '${module.defaultQuestionCount} câu',
                          bg: const Color(0xFFECFDF3),
                          color: const Color(0xFF166534),
                        ),
                      if (module.minutes > 0) ...[
                        const SizedBox(width: 8),
                        _Tag(
                          text: '${module.minutes} phút',
                          bg: const Color(0xFFFFFBEB),
                          color: const Color(0xFFB45309),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.bg, required this.color});

  final String text;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.history});

  final List<QuizHistoryItem> history;

  @override
  Widget build(BuildContext context) {
    final maxScoreItem = _highestScore(history);
    final average = _averageScore(history);
    final lastDate = _latestDate(history);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: QuizDetailPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tiến trình của bạn',
            style: TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Điểm cao nhất',
                  style: TextStyle(color: QuizDetailPalette.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${maxScoreItem.$1}',
                  style: const TextStyle(
                    color: QuizDetailPalette.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (maxScoreItem.$2 != null)
                  Text(
                    'ngày ${DateFormat('dd/MM/yyyy').format(maxScoreItem.$2!)}',
                    style: const TextStyle(
                      color: QuizDetailPalette.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.replay_rounded,
            label: 'Số lần làm bài',
            value: '${history.length} lần',
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.star_rounded,
            label: 'Điểm trung bình',
            value: '$average',
          ),
          const SizedBox(height: 10),
          _ProgressRow(
            icon: Icons.history_rounded,
            label: 'Lần làm gần nhất',
            value: lastDate,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: QuizDetailPalette.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: QuizDetailPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: QuizDetailPalette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(color: Color(0xFFD7C9D2))),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: QuizDetailPalette.textSecondary),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

(int, DateTime?) _highestScore(List<QuizHistoryItem> history) {
  if (history.isEmpty) {
    return (0, null);
  }

  var bestScore = -1;
  DateTime? bestDate;
  for (final item in history) {
    final score = _resolveHistoryScore(item);
    if (score > bestScore) {
      bestScore = score;
      bestDate = item.createdAt;
    }
  }

  return (bestScore < 0 ? 0 : bestScore, bestDate);
}

int _averageScore(List<QuizHistoryItem> history) {
  if (history.isEmpty) {
    return 0;
  }

  var total = 0;
  for (final item in history) {
    total += _resolveHistoryScore(item);
  }

  return (total / history.length).round();
}

String _latestDate(List<QuizHistoryItem> history) {
  final dates = history
      .map((item) => item.createdAt)
      .whereType<DateTime>()
      .toList();
  if (dates.isEmpty) {
    return '-';
  }
  dates.sort((a, b) => b.compareTo(a));
  return DateFormat('dd/MM/yyyy').format(dates.first);
}

int _resolveHistoryScore(QuizHistoryItem item) {
  if (item.type == 'module' || item.submissionType == 'exam') {
    return item.score.inferredTotalScore;
  }
  return item.score.totalScore;
}

int _displayMinutes(QuizSummary quiz) {
  if (quiz.modules.isNotEmpty) {
    var total = 0;
    for (final module in quiz.modules) {
      if (module.minutes > 0) {
        total += module.minutes;
      }
    }
    if (total > 0) {
      return total;
    }
  }
  return quiz.minute;
}

String _formatTime(int minutes) {
  if (minutes <= 0) {
    return 'Không giới hạn';
  }

  final hour = minutes ~/ 60;
  final remain = minutes % 60;
  if (hour > 0) {
    return '$hour giờ ${remain.toString()} phút';
  }
  return '$minutes phút';
}
