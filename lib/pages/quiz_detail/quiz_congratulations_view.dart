import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_constants.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edupen/pages/quiz_detail/quiz_result_view.dart';
import 'package:flutter/material.dart';

class QuizCongratulationsView extends StatefulWidget {
  const QuizCongratulationsView({
    super.key,
    required this.resultUuid,
    required this.quizId,
    required this.quizName,
    required this.questionCount,
    this.resultEndpointTemplate,
  });

  final String resultUuid;
  final String quizId;
  final String quizName;
  final int questionCount;
  final String? resultEndpointTemplate;

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
        quizId: widget.quizId,
        endpointTemplate: widget.resultEndpointTemplate,
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6475F7), Color(0xFF8B26F1), Color(0xFFFA00A7)],
            ),
          ),
          child: Center(
            child: Container(
              width: 512,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 32,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDDF8EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 52,
                      color: Color(0xFF0B8A5A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '🎉 Chúc mừng!',
                    style: TextStyle(
                      color: QuizDetailPalette.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF5B6475),
                        fontSize: 20,
                        height: 1.45,
                      ),
                      children: [
                        TextSpan(text: 'Bạn đã hoàn thành bài thi một cách '),
                        TextSpan(
                          text: 'xuất sắc',
                          style: TextStyle(
                            color: Color(0xFF5B21B6),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(text: '!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(height: 1, color: const Color(0xFFE5E7EB)),
                  const SizedBox(height: 22),
                  const Text(
                    'Kết quả của bạn đã được ghi nhận. Hãy tiếp tục giữ vững phong độ và chinh phục những thử thách tiếp theo 🚀',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 18,
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _isOpeningResult ? null : _openResult,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F1BDB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
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
      ),
    );
  }
}
