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
  });
}

    testWidgets('Operation fields can be filled', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find key field
      final keyField = find.byWidgetPredicate(
        (widget) => widget is TextField && 
                   widget.decoration?.labelText == 'Key'
      );
      expect(keyField, findsOneWidget);
      
      await tester.tap(keyField);
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'test_key');
      await tester.pumpAndSettle();

      // Find value field
      final valueField = find.byWidgetPredicate(
        (widget) => widget is TextField && 
                   widget.decoration?.labelText == 'Value'
      );
      expect(valueField, findsOneWidget);
      
      await tester.tap(valueField);
      await tester.pumpAndSettle();
      await tester.enterText(valueField, 'test_value');
      await tester.pumpAndSettle();
    });

    testWidgets('Operation buttons are disabled when disconnected', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find operation buttons
      final getButton = find.ancestor(
        of: find.text('GET'),
        matching: find.byType(ElevatedButton),
      );
      final setButton = find.ancestor(
        of: find.text('SET'),
        matching: find.byType(ElevatedButton),
      );
      final deleteButton = find.ancestor(
        of: find.text('DELETE'),
        matching: find.byType(ElevatedButton),
      );
      final keysButton = find.ancestor(
        of: find.text('KEYS'),
        matching: find.byType(ElevatedButton),
      );

      // Verify buttons exist
      expect(getButton, findsOneWidget);
      expect(setButton, findsOneWidget);
      expect(deleteButton, findsOneWidget);
      expect(keysButton, findsOneWidget);

      // Operation buttons should be disabled when disconnected
      final getButtonWidget = tester.widget<ElevatedButton>(getButton);
      final setButtonWidget = tester.widget<ElevatedButton>(setButton);
      final deleteButtonWidget = tester.widget<ElevatedButton>(deleteButton);
      final keysButtonWidget = tester.widget<ElevatedButton>(keysButton);

      expect(getButtonWidget.onPressed, isNull);
      expect(setButtonWidget.onPressed, isNull);
      expect(deleteButtonWidget.onPressed, isNull);
      expect(keysButtonWidget.onPressed, isNull);
    });

    testWidgets('Connection attempt with public broker', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Set broker to a public one
      final brokerField = find.byWidgetPredicate(
        (widget) => widget is TextField && 
                   widget.decoration?.labelText == 'MQTT Broker'
      );
      
      await tester.tap(brokerField);
      await tester.pumpAndSettle();
      await tester.enterText(brokerField, 'broker.hivemq.com');
      await tester.pumpAndSettle();

      // Try to connect
      final connectButton = find.ancestor(
        of: find.text('Connect'),
        matching: find.byType(ElevatedButton),
      );
      
      await tester.tap(connectButton);
      await tester.pumpAndSettle();
      
      // Wait a bit for connection attempt
      await tester.pump(const Duration(seconds: 3));
      
      // Check if status changed (connection may succeed or fail, both are valid for testing)
      // We just want to ensure the UI responds to connection attempts
      final statusText = find.textContaining('Status:');
      expect(statusText, findsOneWidget);
    });

    testWidgets('Refresh data button works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find refresh button
      final refreshButton = find.text('Refresh');
      expect(refreshButton, findsOneWidget);
      
      // Tap refresh button
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();
      
      // Should complete without errors
    });
  });
}
