import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh/widgets/suggestion_popup.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('SuggestionPopup', () {
    testWidgets('renders all suggestions', (tester) async {
      await tester.pumpWidget(wrap(SuggestionPopup(
        suggestions: ['git status', 'git log', 'git diff'],
        selectedIndex: -1,
        onSelect: (_) {},
      )));
      expect(find.text('git status'), findsOneWidget);
      expect(find.text('git log'), findsOneWidget);
      expect(find.text('git diff'), findsOneWidget);
    });

    testWidgets('caps display at 8 items', (tester) async {
      final cmds = List.generate(10, (i) => 'cmd$i');
      await tester.pumpWidget(wrap(SuggestionPopup(
        suggestions: cmds,
        selectedIndex: -1,
        onSelect: (_) {},
        maxHeight: 400,
      )));
      for (int i = 0; i < 8; i++) {
        expect(find.text('cmd$i'), findsOneWidget);
      }
      expect(find.text('cmd8'), findsNothing);
      expect(find.text('cmd9'), findsNothing);
    });

    testWidgets('calls onSelect when item tapped', (tester) async {
      String? selected;
      await tester.pumpWidget(wrap(SuggestionPopup(
        suggestions: ['git status', 'git log'],
        selectedIndex: -1,
        onSelect: (s) => selected = s,
      )));
      await tester.tap(find.text('git log'));
      expect(selected, 'git log');
    });

    testWidgets('selected item has blue highlight background', (tester) async {
      await tester.pumpWidget(wrap(SuggestionPopup(
        suggestions: ['git status', 'git log'],
        selectedIndex: 0,
        onSelect: (_) {},
      )));
      final highlighted = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.color == const Color(0xFF1E3A5F);
      });
      expect(highlighted.length, 1);
    });
  });
}
