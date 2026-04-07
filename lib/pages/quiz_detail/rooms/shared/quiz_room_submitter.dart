import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/quiz_detail/quiz_congratulations_view.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/quiz_detail_repository.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:flutter/material.dart';

Future<bool> submitQuizRoom({
  required BuildContext context,
  required QuizRoomData room,
  required QuizRoomAnswerState answers,
  required int usedSeconds,
  Map<String, dynamic>? moduleTimes,
  List<String>? questionIdsOverride,
}) async {
  try {
    final submit = await QuizDetailRepository.instance.submitQuiz(
      room: room,
      selectedOptions: answers.selectedOptions,
      textAnswers: answers.textAnswers,
      multipleChoiceAnswers: answers.multipleChoiceAnswers,
      yesNoAnswers: answers.yesNoAnswers,
      dragDropAnswers: answers.dragDropAnswers,
      markedFlags: answers.markedFlags,
      moduleTimes: moduleTimes,
      usedSeconds: usedSeconds,
      questionIdsOverride: questionIdsOverride,
    );

    if (!context.mounted) {
      return false;
    }

    final opened = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuizCongratulationsView(
          resultUuid: submit.uuid,
          quizId: room.quiz.id,
          quizName: room.quiz.name,
          questionCount: room.quiz.questionCount,
          resultEndpointTemplate: room.resultEndpointTemplate,
        ),
      ),
    );

    if (!context.mounted) {
      return false;
    }

    if (opened == true) {
      Navigator.of(context).pop(true);
      return true;
    }

    return false;
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
    return false;
  }
}
