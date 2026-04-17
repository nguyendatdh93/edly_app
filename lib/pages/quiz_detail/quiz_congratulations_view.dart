import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edly/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edly/pages/quiz_detail/quiz_result_view.dart';
import 'package:flutter/material.dart';

class QuizCongratulationsView extends StatefulWidget {
  const QuizCongratulationsView({
    super.key,
    required this.resultUuid,
    required this.quizName,
    required this.questionCount,
  });

  final String resultUuid;
  final String quizName;
  final int questionCount;

  @override
  State<QuizCongratulationsView> createState() =>
      _QuizCongratulationsViewState();
}

class _QuizCongratulationsViewState extends State<QuizCongratulationsView> {
  bool _isOpeningResult = false;

  Future<void> _openResult() async {
    if (_isOpeningResult) {
      return;
    }

    setState(() {
      _isOpeningResult = true;
    });

    try {
      final result = await QuizDetailRepository.instance.fetchResult(
        widget.resultUuid,
      );
      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizResultView(
            result: result,
            quizName: widget.quizName,
            questionCount: widget.questionCount,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        _isOpeningResult = false;
      });
    }
  }

  @override
Widget build(BuildContext context) {
  return PopScope(
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Container(
          width: 512,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 36,
                  color: Color(0xFF15803D),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Nộp bài thành công',
                style: TextStyle(
                  color: QuizDetailPalette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Bài làm của bạn đã được ghi nhận trong hệ thống.',
                style: TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 17,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFFE5E7EB)),
              const SizedBox(height: 20),
              const Text(
                'Bạn có thể xem kết quả ngay bây giờ để kiểm tra số câu đã làm, đáp án và phần giải thích chi tiết.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isOpeningResult ? null : _openResult,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isOpeningResult
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Xem kết quả'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
