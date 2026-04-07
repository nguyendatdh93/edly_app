import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';

class QuizRoomAnswerState {
  final Map<String, String> selectedOptions = <String, String>{};
  final Map<String, String> textAnswers = <String, String>{};
  final Map<String, Set<String>> multipleChoiceAnswers =
      <String, Set<String>>{};
  final Map<String, Map<String, bool>> yesNoAnswers =
      <String, Map<String, bool>>{};
  final Map<String, List<String>> dragDropAnswers = <String, List<String>>{};
  final Map<String, bool> markedFlags = <String, bool>{};

  void ensureDefaultsForQuestion(QuizQuestion question) {
    final type = question.type.toLowerCase().trim();
    if (type == 'yes-no') {
      yesNoAnswers.putIfAbsent(question.id, () {
        final value = <String, bool>{};
        for (final option in question.options) {
          if (option.id.isEmpty) {
            continue;
          }
          value[option.id] = false;
        }
        return value;
      });
    }

    if (type == 'multiple-choices') {
      multipleChoiceAnswers.putIfAbsent(question.id, () => <String>{});
    }

    if (type == 'drag-drop') {
      dragDropAnswers.putIfAbsent(question.id, () => <String>[]);
    }
  }

  bool isQuestionAnswered(QuizQuestion question) {
    final type = question.type.toLowerCase().trim();
    if (type == 'single-choice') {
      return (selectedOptions[question.id] ?? '').trim().isNotEmpty;
    }

    if (type == 'multiple-choices') {
      final picked = multipleChoiceAnswers[question.id] ?? const <String>{};
      return picked.isNotEmpty;
    }

    if (type == 'yes-no') {
      final values = yesNoAnswers[question.id] ?? const <String, bool>{};
      return values.values.any((item) => item == true);
    }

    if (type == 'drag-drop') {
      final values = dragDropAnswers[question.id] ?? const <String>[];
      return values.isNotEmpty;
    }

    if (isTextAnswerType(type)) {
      return (textAnswers[question.id] ?? '').trim().isNotEmpty;
    }

    if (question.options.isNotEmpty) {
      return (selectedOptions[question.id] ?? '').trim().isNotEmpty;
    }

    return (textAnswers[question.id] ?? '').trim().isNotEmpty;
  }

  int answeredCount(Iterable<QuizQuestion> questions) {
    var count = 0;
    for (final question in questions) {
      if (isQuestionAnswered(question)) {
        count += 1;
      }
    }
    return count;
  }

  bool isMarked(String questionId) => markedFlags[questionId] == true;

  void toggleMarked(String questionId) {
    markedFlags[questionId] = !(markedFlags[questionId] == true);
  }

  void setSingleChoice(String questionId, String optionId) {
    selectedOptions[questionId] = optionId;
  }

  void setTextAnswer(String questionId, String value) {
    textAnswers[questionId] = value;
  }

  void toggleMultipleChoice(String questionId, String optionId, bool checked) {
    final picked = multipleChoiceAnswers.putIfAbsent(
      questionId,
      () => <String>{},
    );
    if (checked) {
      picked.add(optionId);
      return;
    }
    picked.remove(optionId);
  }

  void setYesNoValue(String questionId, String optionId, bool checked) {
    final map = yesNoAnswers.putIfAbsent(questionId, () => <String, bool>{});
    map[optionId] = checked;
  }

  void toggleDragDropOption(String questionId, String optionId) {
    final list = dragDropAnswers.putIfAbsent(questionId, () => <String>[]);
    if (list.contains(optionId)) {
      list.remove(optionId);
      return;
    }
    list.add(optionId);
  }
}
