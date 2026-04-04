import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/course_detail/course_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:flutter/foundation.dart';

class QuizDetailController extends ChangeNotifier {
  QuizDetailController({
    QuizDetailRepository? repository,
  }) : _repository = repository ?? QuizDetailRepository.instance;

  final QuizDetailRepository _repository;

  QuizDetailData? data;
  bool isLoading = false;
  bool isPurchasing = false;
  String? errorMessage;

  Future<void> load(String quizId) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      data = await _repository.fetchQuizDetail(quizId);
    } on AppException catch (error) {
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<BalancePurchaseResult?> purchaseByBalance({
    required String quizId,
    required String courseId,
  }) async {
    isPurchasing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.purchaseQuizByBalance(
        quizId: quizId,
        courseId: courseId,
      );
      data = await _repository.fetchQuizDetail(quizId);
      return result;
    } on AppException catch (error) {
      errorMessage = error.message;
      return null;
    } finally {
      isPurchasing = false;
      notifyListeners();
    }
  }
}
