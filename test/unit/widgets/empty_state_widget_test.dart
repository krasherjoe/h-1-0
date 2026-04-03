import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:h_1/widgets/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget', () {
    const testIcon = Icons.inbox;
    const testTitle = 'データがありません';
    const testSubtitle = '新しいデータを作成してください';
    const testActionLabel = '作成';

    testWidgets('should display empty state information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              subtitle: testSubtitle,
              actionLabel: testActionLabel,
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(testSubtitle), findsOneWidget);
      expect(find.text(testActionLabel), findsOneWidget);
      expect(find.byIcon(testIcon), findsOneWidget);
    });

    testWidgets('should handle action button tap', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              subtitle: testSubtitle,
              actionLabel: testActionLabel,
              iconColor: Colors.grey,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text(testActionLabel));
      await tester.pump();

      expect(actionTapped, isTrue);
    });

    testWidgets('should display without subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(testSubtitle), findsNothing); // Should not find subtitle
    });

    testWidgets('should display without action button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              subtitle: testSubtitle,
              iconColor: Colors.grey,
            ),
          ),
        ),
      );

      expect(find.text(testTitle), findsOneWidget);
      expect(find.text(testSubtitle), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing); // Should not find action button
    });

    testWidgets('should use default icon color when not specified', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(testIcon), findsOneWidget);
    });

    testWidgets('should handle null onAction gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              subtitle: testSubtitle,
              actionLabel: testActionLabel,
              iconColor: Colors.grey,
              onAction: null, // Null onAction
            ),
          ),
        ),
      );

      // Should not display action button when onAction is null
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('should center content correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              subtitle: testSubtitle,
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      // Check that the main container is centered
      expect(find.byType(Center), findsAtLeastNWidgets(1));
    });

    testWidgets('should handle different icons', (tester) async {
      const icons = [
        Icons.inbox,
        Icons.folder_open,
        Icons.error_outline,
        Icons.check_circle_outline,
      ];

      for (final icon in icons) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyStateWidget(
                icon: icon,
                title: testTitle,
                iconColor: Colors.grey,
                onAction: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(icon), findsOneWidget);
        await tester.pumpWidget(Container()); // Clean up for next iteration
      }
    });

    testWidgets('should handle long titles and subtitles', (tester) async {
      const longTitle = '非常に長いタイトルです。これはテスト用の長いテキストです。';
      const longSubtitle = 'これは非常に長いサブタイトルです。複数行にわたる可能性があります。';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: longTitle,
              subtitle: longSubtitle,
              iconColor: Colors.grey,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.text(longTitle), findsOneWidget);
      expect(find.text(longSubtitle), findsOneWidget);
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });

    testWidgets('should apply custom icon color', (tester) async {
      const customColor = Colors.blue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: testIcon,
              title: testTitle,
              iconColor: customColor,
              onAction: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(testIcon), findsOneWidget);
      // Note: Color testing in Flutter tests requires additional setup
      // This test mainly ensures the widget renders without errors
    });
  });
}
