import 'dart:math' as math;

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';

String stripHtml(String raw) {
  if (raw.isEmpty) {
    return '';
  }

  var text = raw
      .replaceAll(
        RegExp(r'<style[^>]*>[\\s\\S]*?<\\/style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<script[^>]*>[\\s\\S]*?<\\/script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');

  text = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
  return text;
}

String formatDuration(int seconds) {
  final value = seconds.clamp(0, 360000);
  final hour = value ~/ 3600;
  final minute = (value % 3600) ~/ 60;
  final second = value % 60;

  String twoDigit(int number) => number.toString().padLeft(2, '0');

  if (hour > 0) {
    return '${twoDigit(hour)}:${twoDigit(minute)}:${twoDigit(second)}';
  }
  return '${twoDigit(minute)}:${twoDigit(second)}';
}

List<QuizRoomModule> normalizeTopModules(QuizRoomData room) {
  if (room.modules.isNotEmpty) {
    return room.modules;
  }

  if (room.questions.isEmpty) {
    return const [];
  }

  return [
    QuizRoomModule(
      id: 'default',
      name: room.quiz.name,
      minute: room.quiz.minute,
      level: 0,
      parentId: '',
      questions: room.questions,
      children: const [],
    ),
  ];
}

List<QuizQuestion> collectModuleQuestions(QuizRoomModule module) {
  final rows = <QuizQuestion>[...module.questions];
  for (final child in module.children) {
    rows.addAll(collectModuleQuestions(child));
  }
  return rows;
}

List<QuizQuestion> collectQuestionsByModules(List<QuizRoomModule> modules) {
  final rows = <QuizQuestion>[];
  for (final module in modules) {
    rows.addAll(collectModuleQuestions(module));
  }
  return rows;
}

int resolveRoomDurationSeconds(QuizRoomData room, {int fallbackMinutes = 30}) {
  if (room.quiz.minute > 0) {
    return room.quiz.minute * 60;
  }

  final moduleMinutes = _sumModuleMinutes(room.modules);
  if (moduleMinutes > 0) {
    return moduleMinutes * 60;
  }

  final byQuestion = math.max(room.questions.length, 1) * 45;
  return math.max(byQuestion, fallbackMinutes * 60);
}

int _sumModuleMinutes(List<QuizRoomModule> modules) {
  var total = 0;
  for (final module in modules) {
    total += module.minute;
    total += _sumModuleMinutes(module.children);
  }
  return total;
}

bool isTextAnswerType(String type) {
  switch (type.toLowerCase().trim()) {
    case 'essay':
    case 'essay-yes-no':
    case 'short-answer':
    case 'numeric':
    case 'long-answer':
      return true;
    default:
      return false;
  }
}

bool isSelectableOptionType(String type) {
  switch (type.toLowerCase().trim()) {
    case 'single-choice':
    case 'multiple-choices':
    case 'yes-no':
    case 'drag-drop':
      return true;
    default:
      return false;
  }
}
