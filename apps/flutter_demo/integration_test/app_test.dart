import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MerkleKV Mobile Demo Tests', () {
    testWidgets('App launches and displays main UI', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify main UI elements for simplified counter app
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      expect(find.text('You have pushed the button this many times:'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Counter increment works correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify initial counter state
      expect(find.text('0'), findsOneWidget);

      // Tap the increment button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify counter incremented
      expect(find.text('0'), findsNothing);
      expect(find.text('1'), findsOneWidget);

      // Tap again
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify counter incremented again
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('UI elements are properly displayed', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify AppBar
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      
      // Verify main content
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      
      // Verify text styling
      expect(find.text('You have pushed the button this many times:'), findsOneWidget);
    });

    testWidgets('Counter can be incremented multiple times', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      final incrementButton = find.byIcon(Icons.add);
      
      // Test multiple increments
      for (int i = 1; i <= 5; i++) {
        await tester.tap(incrementButton);
        await tester.pumpAndSettle();
        expect(find.text(i.toString()), findsOneWidget);
      }
    });

    testWidgets('App theme and styling works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify theme elements
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Verify Material 3 components are present
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.title, isA<Text>());
      
      // Verify FloatingActionButton has correct icon
      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
      expect(fab.child, isA<Icon>());
    });

    testWidgets('Screen structure is correct', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify the main structure
      expect(find.byType(Center), findsWidgets);
      expect(find.byType(Column), findsWidgets);
      
      // Verify we have the right number of text widgets
      expect(find.byType(Text), findsAtLeastNWidgets(3)); // Title, counter label, counter value
    });
  });
}
