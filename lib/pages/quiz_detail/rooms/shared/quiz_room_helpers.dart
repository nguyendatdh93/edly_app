import 'dart:math' as math;

import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';

String stripHtml(String raw) {
  if (raw.trim().isEmpty) {
    return '';
  }

  var text = raw
      .replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?<\/style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?<\/script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|li|tr|h[1-6]|blockquote)>', caseSensitive: false),
        '\n',
      )
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '- ')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('\u00A0', ' ');

  text = _decodeHtmlEntities(text);

  final lines = text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final normalizedLines = _mergeLikelySplitMathLines(lines);
  return normalizedLines.join('\n').trim();
}

String _decodeHtmlEntities(String input) {
  if (input.isEmpty) {
    return '';
  }

  return input.replaceAllMapped(
    RegExp(r'&(#[0-9]+|#x[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]+);'),
    (match) {
      final entity = match.group(1) ?? '';
      if (entity.isEmpty) {
        return match.group(0) ?? '';
      }

      if (entity.startsWith('#')) {
        final isHex =
            entity.length > 2 && (entity[1] == 'x' || entity[1] == 'X');
        final rawCodePoint = entity.substring(isHex ? 2 : 1);
        final codePoint = int.tryParse(rawCodePoint, radix: isHex ? 16 : 10);
        if (codePoint == null ||
            codePoint <= 0 ||
            codePoint > 0x10FFFF ||
            (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
          return match.group(0) ?? '';
        }
        return String.fromCharCode(codePoint);
      }

      final named =
          _namedHtmlEntities[entity] ??
          _namedHtmlEntities[entity.toLowerCase()];
      return named ?? (match.group(0) ?? '');
    },
  );
}

List<String> _mergeLikelySplitMathLines(List<String> lines) {
  if (lines.length < 3) {
    return lines;
  }

  final normalized = <String>[];
  var index = 0;

  while (index < lines.length) {
    final run = <String>[];
    var cursor = index;
    while (cursor < lines.length && _isSingleTokenLine(lines[cursor])) {
      run.add(lines[cursor].trim());
      cursor += 1;
    }

    if (_shouldMergeTokenRun(run)) {
      normalized.add(run.join());
      index = cursor;
      continue;
    }

    normalized.add(lines[index]);
    index += 1;
  }

  return normalized;
}

bool _isSingleTokenLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9=+\-*/^().,:;]$').hasMatch(trimmed);
}

bool _shouldMergeTokenRun(List<String> run) {
  if (run.length < 3) {
    return false;
  }

  final merged = run.join();
  if (RegExp(r'[0-9=+\-*/^]').hasMatch(merged)) {
    return true;
  }

  final looksLikeWord = RegExp(r'^[A-Za-z]+$').hasMatch(merged);
  final hasLowercase = merged != merged.toUpperCase();
  return looksLikeWord && hasLowercase && run.length >= 4;
}

const Map<String, String> _namedHtmlEntities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'laquo': '\u00AB',
  'raquo': '\u00BB',
  'lsquo': '\u2018',
  'rsquo': '\u2019',
  'ldquo': '\u201C',
  'rdquo': '\u201D',
  'ndash': '\u2013',
  'mdash': '\u2014',
  'hellip': '\u2026',
  'bull': '\u2022',
  'middot': '\u00B7',
  'copy': '\u00A9',
  'reg': '\u00AE',
  'deg': '\u00B0',
  'plusmn': '\u00B1',
  'times': '\u00D7',
  'divide': '\u00F7',
  'Agrave': '\u00C0',
  'Aacute': '\u00C1',
  'Acirc': '\u00C2',
  'Atilde': '\u00C3',
  'Auml': '\u00C4',
  'Aring': '\u00C5',
  'AElig': '\u00C6',
  'Ccedil': '\u00C7',
  'Egrave': '\u00C8',
  'Eacute': '\u00C9',
  'Ecirc': '\u00CA',
  'Euml': '\u00CB',
  'Igrave': '\u00CC',
  'Iacute': '\u00CD',
  'Icirc': '\u00CE',
  'Iuml': '\u00CF',
  'Ntilde': '\u00D1',
  'Ograve': '\u00D2',
  'Oacute': '\u00D3',
  'Ocirc': '\u00D4',
  'Otilde': '\u00D5',
  'Ouml': '\u00D6',
  'Oslash': '\u00D8',
  'Ugrave': '\u00D9',
  'Uacute': '\u00DA',
  'Ucirc': '\u00DB',
  'Uuml': '\u00DC',
  'Yacute': '\u00DD',
  'agrave': '\u00E0',
  'aacute': '\u00E1',
  'acirc': '\u00E2',
  'atilde': '\u00E3',
  'auml': '\u00E4',
  'aring': '\u00E5',
  'aelig': '\u00E6',
  'ccedil': '\u00E7',
  'egrave': '\u00E8',
  'eacute': '\u00E9',
  'ecirc': '\u00EA',
  'euml': '\u00EB',
  'igrave': '\u00EC',
  'iacute': '\u00ED',
  'icirc': '\u00EE',
  'iuml': '\u00EF',
  'ntilde': '\u00F1',
  'ograve': '\u00F2',
  'oacute': '\u00F3',
  'ocirc': '\u00F4',
  'otilde': '\u00F5',
  'ouml': '\u00F6',
  'oslash': '\u00F8',
  'ugrave': '\u00F9',
  'uacute': '\u00FA',
  'ucirc': '\u00FB',
  'uuml': '\u00FC',
  'yacute': '\u00FD',
  'yuml': '\u00FF',
};

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
