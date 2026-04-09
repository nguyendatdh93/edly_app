import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/comprehension.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/drag_drop.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/essay.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/essay_yes_no.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/long_answer.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/multiple_choices.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/single_choice.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/type/yes_no.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/widgets/html_math_view.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_answer_state.dart';
import 'package:flutter/material.dart';

class DefaultRoomQuestionCard extends StatelessWidget {
  const DefaultRoomQuestionCard({
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

    final displayLabel = question.sort > 0 ? question.sort : questionNumber;
    final questionHtml = question.content.trim().isNotEmpty
        ? question.content
        : question.title;
    final isComprehensionWithChildren =
        question.type.toLowerCase().trim() == 'comprehension' &&
        question.children.isNotEmpty;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final useSplitLayout = isLandscape || size.width >= 760;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;
        final content = useSplitLayout
            ? _buildSplitLayout(
                questionHtml: questionHtml,
                isComprehensionWithChildren: isComprehensionWithChildren,
              )
            : _buildStackedLayout(
                questionHtml: questionHtml,
                isComprehensionWithChildren: isComprehensionWithChildren,
              );

        return Container(
          width: double.infinity,
          height: hasBoundedHeight ? constraints.maxHeight : null,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Câu $displayLabel/$totalQuestions',
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
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        answerState.isMarked(question.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (hasBoundedHeight) Expanded(child: content) else content,
            ],
          ),
        );
      },
    );
  }

  Widget _buildSplitLayout({
    required String questionHtml,
    required bool isComprehensionWithChildren,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: _SplitPanel(
            title: 'Nội dung câu hỏi',
            child: _buildQuestionHtmlPane(questionHtml),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 12,
          child: _SplitPanel(
            title: isComprehensionWithChildren
                ? 'Danh sách câu hỏi con'
                : 'Trả lời',
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: isComprehensionWithChildren
                  ? _buildComprehensionChildrenList(question.children, depth: 0)
                  : _buildAnswerEditorForQuestion(question, depth: 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackedLayout({
    required String questionHtml,
    required bool isComprehensionWithChildren,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: _SplitPanel(
            title: 'Nội dung câu hỏi',
            child: _buildQuestionHtmlPane(questionHtml),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _SplitPanel(
            title: isComprehensionWithChildren
                ? 'Danh sách câu hỏi con'
                : 'Trả lời',
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: isComprehensionWithChildren
                  ? _buildComprehensionChildrenList(question.children, depth: 0)
                  : _buildAnswerEditorForQuestion(question, depth: 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionHtmlPane(String html) {
    final safeHtml = html.trim().isNotEmpty
        ? html
        : '<p>Không có nội dung mô tả cho câu hỏi này.</p>';

    return DefaultRoomHtmlView(
      html: safeHtml,
      mode: DefaultRoomHtmlViewMode.fill,
      fontSize: 18,
      minHeight: 120,
    );
  }

  Widget _buildComprehensionChildrenList(
    List<QuizQuestion> children, {
    required int depth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++)
          _buildComprehensionChildCard(
            childQuestion: children[index],
            index: index,
            isLast: index == children.length - 1,
            depth: depth,
          ),
      ],
    );
  }

  Widget _buildComprehensionChildCard({
    required QuizQuestion childQuestion,
    required int index,
    required bool isLast,
    required int depth,
  }) {
    answerState.ensureDefaultsForQuestion(childQuestion);

    final childLabel = childQuestion.sort > 0 ? childQuestion.sort : index + 1;
    final childHtml = childQuestion.content.trim().isNotEmpty
        ? childQuestion.content
        : childQuestion.title;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu con $childLabel',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          DefaultRoomHtmlView(
            html: childHtml.trim().isNotEmpty
                ? childHtml
                : '<p>[Không có nội dung]</p>',
            fontSize: 15,
            minHeight: 24,
            maxAutoHeight: 260,
          ),
          const SizedBox(height: 8),
          _buildAnswerEditorForQuestion(childQuestion, depth: depth + 1),
        ],
      ),
    );
  }

  Widget _buildAnswerEditorForQuestion(
    QuizQuestion target, {
    required int depth,
  }) {
    final type = target.type.toLowerCase().trim();

    switch (type) {
      case 'single-choice':
        return SingleChoice(
          question: target,
          selectedOptionId: answerState.selectedOptions[target.id] ?? '',
          onSelect: (optionId) {
            answerState.setSingleChoice(target.id, optionId);
            onChanged();
          },
        );
      case 'multiple-choices':
        return MultipleChoices(
          question: target,
          selected:
              answerState.multipleChoiceAnswers[target.id] ?? const <String>{},
          onToggle: (optionId, checked) {
            answerState.toggleMultipleChoice(target.id, optionId, checked);
            onChanged();
          },
        );
      case 'yes-no':
        return YesNo(
          question: target,
          values: answerState.yesNoAnswers[target.id] ?? const <String, bool>{},
          onToggle: (optionId, checked) {
            answerState.setYesNoValue(target.id, optionId, checked);
            onChanged();
          },
        );
      case 'drag-drop':
        return DragDrop(
          question: target,
          selected: answerState.dragDropAnswers[target.id] ?? const <String>[],
          onToggle: (optionId) {
            answerState.toggleDragDropOption(target.id, optionId);
            onChanged();
          },
        );
      case 'essay':
        return Essay(
          questionId: target.id,
          initialValue: answerState.textAnswers[target.id] ?? '',
          hintText: 'Nhập câu trả lời',
          onChanged: (value) {
            answerState.setTextAnswer(target.id, value);
            onChanged();
          },
        );
      case 'essay-yes-no':
        return EssayYesNo(
          questionId: target.id,
          initialValue: answerState.textAnswers[target.id] ?? '',
          onChanged: (value) {
            answerState.setTextAnswer(target.id, value);
            onChanged();
          },
        );
      case 'long-answer':
        return LongAnswer(
          questionId: target.id,
          initialValue: answerState.textAnswers[target.id] ?? '',
          onChanged: (value) {
            answerState.setTextAnswer(target.id, value);
            onChanged();
          },
        );
      case 'comprehension':
        if (target.children.isNotEmpty && depth < 4) {
          return _buildComprehensionChildrenList(target.children, depth: depth);
        }
        return Comprehension(
          question: target,
          selectedOptionId: answerState.selectedOptions[target.id] ?? '',
          textValue: answerState.textAnswers[target.id] ?? '',
          onSelect: (optionId) {
            answerState.setSingleChoice(target.id, optionId);
            onChanged();
          },
          onTextChanged: (value) {
            answerState.setTextAnswer(target.id, value);
            onChanged();
          },
        );
      default:
        if (target.options.isNotEmpty) {
          return SingleChoice(
            question: target,
            selectedOptionId: answerState.selectedOptions[target.id] ?? '',
            onSelect: (optionId) {
              answerState.setSingleChoice(target.id, optionId);
              onChanged();
            },
          );
        }

        return Essay(
          questionId: target.id,
          initialValue: answerState.textAnswers[target.id] ?? '',
          hintText: 'Nhập câu trả lời',
          onChanged: (value) {
            answerState.setTextAnswer(target.id, value);
            onChanged();
          },
        );
    }
  }
}

class _SplitPanel extends StatelessWidget {
  const _SplitPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}
