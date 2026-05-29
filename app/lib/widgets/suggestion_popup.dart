import 'package:flutter/material.dart';

class SuggestionPopup extends StatelessWidget {
  final List<String> suggestions;
  final int selectedIndex;
  final void Function(String) onSelect;
  final double maxHeight;

  const SuggestionPopup({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
    this.maxHeight = 160,
  });

  @override
  Widget build(BuildContext context) {
    final items = suggestions.take(8).toList();
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        border: Border.all(color: const Color(0xFF2A2A2A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final selected = i == selectedIndex;
          return InkWell(
            onTap: () => onSelect(items[i]),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                items[i],
                style: TextStyle(
                  color: selected ? const Color(0xFF7DD3FC) : const Color(0xFFD4D4D4),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
