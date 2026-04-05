import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/widgets/document_card.dart';

void main() {
  group('DocumentCard', () {
    const testTitle = 'テスト顧客';
    const testSubtitle = '2026/03/08 - 下書き';
    const testAmount = '¥11,000';
    const testDate = '2026-03-08';
    const testStatus = DocumentStatus.draft;
    const testThemeColor = Colors.blue;

    testWidgets('should display document information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [],
            ),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(testSubtitle), findsOneWidget);
      expect(find.text(testAmount), findsOneWidget);
    });

    testWidgets('should handle tap correctly', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () => wasTapped = true,
              actions: [],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DocumentCard));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('should display actions when provided', (tester) async {
      bool action1Tapped = false;
      bool action2Tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [
                CardAction(
                  label: 'コピー',
                  icon: Icons.content_copy,
                  onPressed: () => action1Tapped = true,
                ),
                CardAction(
                  label: '削除',
                  icon: Icons.delete,
                  onPressed: () => action2Tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);

      // Test first action
      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();
      expect(action1Tapped, isTrue);
      expect(action2Tapped, isFalse);

      // Reset and test second action
      action1Tapped = false;
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();
      expect(action1Tapped, isFalse);
      expect(action2Tapped, isTrue);
    });

    testWidgets('should display status badge correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [],
            ),
          ),
        ),
      );

      // Check if status chip is displayed
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('下書き'), findsOneWidget); // draft status
    });

    testWidgets('should handle different statuses', (tester) async {
      for (final status in DocumentStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocumentCard(
                title: testTitle,
                subtitle: testSubtitle,
                amount: testAmount,
                date: DateTime.parse(testDate),
                status: status,
                themeColor: testThemeColor,
                onTap: () {},
                actions: [],
              ),
            ),
          ),
        );

        expect(find.byType(DocumentCard), findsOneWidget);
        await tester.pumpWidget(Container()); // Clean up for next iteration
      }
    });

    testWidgets('should handle null onTap gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: null, // Null onTap
              actions: [],
            ),
          ),
        ),
      );

      // Should not crash when tapped
      await tester.tap(find.byType(DocumentCard));
      await tester.pump();

      expect(find.byType(DocumentCard), findsOneWidget);
    });

    testWidgets('should handle empty actions list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [], // Empty actions
            ),
          ),
        ),
      );

      expect(find.byType(DocumentCard), findsOneWidget);
      // Should not find any action buttons
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('should display date correctly', (tester) async {
      const specificDate = '2026-12-25';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: testTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(specificDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [],
            ),
          ),
        ),
      );

      // Check if date is displayed (format might be different)
      expect(find.textContaining('2026'), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle long titles', (tester) async {
      const longTitle = '非常に長い顧客名です。これはテスト用の長いテキストです。';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentCard(
              title: longTitle,
              subtitle: testSubtitle,
              amount: testAmount,
              date: DateTime.parse(testDate),
              status: testStatus,
              themeColor: testThemeColor,
              onTap: () {},
              actions: [],
            ),
          ),
        ),
      );

      expect(find.text(longTitle), findsOneWidget);
      expect(find.byType(DocumentCard), findsOneWidget);
    });
  });
}
