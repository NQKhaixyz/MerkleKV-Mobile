import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MerkleKV Mobile Simple Tests', () {
    testWidgets('App launches and displays correct UI', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify main UI elements are present for simplified counter app
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      expect(find.text('You have pushed the button this many times:'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Counter functionality works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify initial state
      expect(find.text('0'), findsOneWidget);

      // Tap the + button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify counter incremented
      expect(find.text('1'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      // Tap again multiple times
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
      }

      // Verify final count
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('UI layout is correct', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify structure
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Center), findsWidgets);
    });

    testWidgets('AppBar displays correct title', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify AppBar title
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Counter display updates correctly', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Test multiple increments
      final incrementButton = find.byIcon(Icons.add);
      
      for (int i = 1; i <= 10; i++) {
        await tester.tap(incrementButton);
        await tester.pumpAndSettle();
        expect(find.text(i.toString()), findsOneWidget);
      }
    });
  });
}
