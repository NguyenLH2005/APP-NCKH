import 'package:flutter/material.dart';

class SuggestionAccordion extends StatefulWidget {
  final String title;
  final String content;
  final Color color;

  const SuggestionAccordion({
    super.key,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  State<SuggestionAccordion> createState() => _SuggestionAccordionState();
}

class _SuggestionAccordionState extends State<SuggestionAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: widget.color.withValues(alpha: 0.5), width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: widget.color,
          collapsedIconColor: widget.color,
          title: Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: widget.color,
              fontSize: 16,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Text(
                widget.content,
                style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
