import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/comprehension.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/drag_drop.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/essay.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/essay_yes_no.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/long_answer.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/multiple_choices.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/single_choice.dart';
import 'package:edupen/pages/quiz_detail/rooms/literature_room/type/yes_no.dart';
import 'package:flutter/material.dart';

class LiteratureRoomQuestionCard extends StatelessWidget {
  const LiteratureRoomQuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.answerState,
    required this.onChanged,
    this.showBookmark = true,
  });

  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final QuizRoomAnswerState answerState;
  final VoidCallback onChanged;
  final bool showBookmark;

  @override
  Widget build(BuildContext context) {
    answerState.ensureDefaultsForQuestion(question);

    final questionText = stripHtml(
      question.content.trim().isNotEmpty ? question.content : question.title,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Câu $questionNumber/$totalQuestions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (showBookmark)
                IconButton(
                  onPressed: () {
                    answerState.toggleMarked(question.id);
                    onChanged();
                  },
                  tooltip: 'Đánh dấu câu hỏi',
                  icon: Icon(
                    answerState.isMarked(question.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: const Color(0xFFF97316),
                  ),
                ),
            ],
          ),
          if (questionText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText(
                questionText,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          _buildAnswerEditor(),
        ],
      ),
    );
  }

  Widget _buildAnswerEditor() {
    final type = question.type.toLowerCase().trim();

    switch (type) {
      case 'single-choice':
        return SingleChoice(
          question: question,
          selectedOptionId: answerState.selectedOptions[question.id] ?? '',
          onSelect: (optionId) {
            answerState.setSingleChoice(question.id, optionId);
            onChanged();
          },
        );
      case 'multiple-choices':
        return MultipleChoices(
          question: question,
          selected:
              answerState.multipleChoiceAnswers[question.id] ??
              const <String>{},
          onToggle: (optionId, checked) {
            answerState.toggleMultipleChoice(question.id, optionId, checked);
            onChanged();
          },
        );
      case 'yes-no':
        return YesNo(
          question: question,
          values:
              answerState.yesNoAnswers[question.id] ?? const <String, bool>{},
          onToggle: (optionId, checked) {
            answerState.setYesNoValue(question.id, optionId, checked);
            onChanged();
          },
        );
      case 'drag-drop':
        return DragDrop(
          question: question,
          selected:
              answerState.dragDropAnswers[question.id] ?? const <String>[],
          onToggle: (optionId) {
            answerState.toggleDragDropOption(question.id, optionId);
            onChanged();
          },
        );
      case 'essay':
        return Essay(
          questionId: question.id,
          initialValue: answerState.textAnswers[question.id] ?? '',
          hintText: 'Nhập câu trả lời',
          onChanged: (value) {
            answerState.setTextAnswer(question.id, value);
            onChanged();
          },
        );
      case 'essay-yes-no':
        return EssayYesNo(
          questionId: question.id,
          initialValue: answerState.textAnswers[question.id] ?? '',
          onChanged: (value) {
            answerState.setTextAnswer(question.id, value);
            onChanged();
          },
        );
      case 'long-answer':
        return LongAnswer(
          questionId: question.id,
          initialValue: answerState.textAnswers[question.id] ?? '',
          onChanged: (value) {
            answerState.setTextAnswer(question.id, value);
            onChanged();
          },
        );
      case 'comprehension':
        return Comprehension(
          question: question,
          selectedOptionId: answerState.selectedOptions[question.id] ?? '',
          textValue: answerState.textAnswers[question.id] ?? '',
          onSelect: (optionId) {
            answerState.setSingleChoice(question.id, optionId);
            onChanged();
          },
          onTextChanged: (value) {
            answerState.setTextAnswer(question.id, value);
            onChanged();
          },
        );
      default:
        if (question.options.isNotEmpty) {
          return SingleChoice(
            question: question,
            selectedOptionId: answerState.selectedOptions[question.id] ?? '',
            onSelect: (optionId) {
              answerState.setSingleChoice(question.id, optionId);
              onChanged();
            },
          );
        }

        return Essay(
          questionId: question.id,
          initialValue: answerState.textAnswers[question.id] ?? '',
          hintText: 'Nhập câu trả lời',
          onChanged: (value) {
            answerState.setTextAnswer(question.id, value);
            onChanged();
          },
        );
    }
  }
}
