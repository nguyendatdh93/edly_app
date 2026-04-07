import 'package:edupen/pages/quiz_detail/quiz_detail_models.dart';
import 'package:edupen/pages/quiz_detail/rooms/shared/quiz_room_helpers.dart';
import 'package:flutter/material.dart';

class DragDrop extends StatelessWidget {
  const DragDrop({
    super.key,
    required this.question,
    required this.selected,
    required this.onToggle,
  });

  final QuizQuestion question;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chạm để sắp xếp lựa chọn theo thứ tự',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var index = 0; index < question.options.length; index++)
              _DragDropOptionChip(
                index: index,
                option: question.options[index],
                order: _selectedOrderOf(selected, question.options[index].id),
                onTap: () => onToggle(question.options[index].id),
              ),
          ],
        ),
      ],
    );
  }

  int? _selectedOrderOf(List<String> values, String optionId) {
    final index = values.indexOf(optionId);
    if (index < 0) {
      return null;
    }
    return index + 1;
  }
}

class _DragDropOptionChip extends StatelessWidget {
  const _DragDropOptionChip({
    required this.index,
    required this.option,
    required this.order,
    required this.onTap,
  });

  final int index;
  final QuizOption option;
  final int? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelText = stripHtml(option.content);
    final label = labelText.isNotEmpty ? labelText : 'Lựa chọn ${index + 1}';
    final isSelected = order != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0E7FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 6),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$order',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF1E1B4B)
                    : const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
