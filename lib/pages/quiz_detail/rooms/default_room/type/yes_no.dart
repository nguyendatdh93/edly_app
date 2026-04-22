import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/default_room/widgets/html_math_view.dart';
import 'package:flutter/material.dart';

class YesNo extends StatelessWidget {
  const YesNo({
    super.key,
    required this.question,
    required this.values,
    required this.onToggle,
  });

  final QuizQuestion question;
  final Map<String, bool> values;
  final void Function(String optionId, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < question.options.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: DefaultRoomHtmlView(
                      html: _optionHtml(index, question.options[index]),
                      fontSize: 15,
                      minHeight: 26,
                      maxAutoHeight: 320,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _YesNoButton(
                      label: 'Đ',
                      selected: values[question.options[index].id] == true,
                      selectedColor: const Color(0xFF2563EB),
                      onTap: () {
                        onToggle(question.options[index].id, true);
                      },
                    ),
                    const SizedBox(width: 8),
                    _YesNoButton(
                      label: 'S',
                      selected:
                          values.containsKey(question.options[index].id) &&
                          values[question.options[index].id] == false,
                      selectedColor: const Color(0xFFEF4444),
                      onTap: () {
                        onToggle(question.options[index].id, false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _optionHtml(int index, QuizOption option) {
    if (option.content.trim().isEmpty) {
      return '<p>[Lựa chọn ${index + 1}]</p>';
    }
    return option.content;
  }
}

class _YesNoButton extends StatelessWidget {
  const _YesNoButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? selectedColor : Colors.white,
          border: Border.all(
            color: selected ? selectedColor : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
