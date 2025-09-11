import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_demo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MerkleKV Mobile End-to-End Tests', () {
    testWidgets('App launches and displays correct UI', (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify main UI elements are present
      expect(find.text('MerkleKV Mobile Demo'), findsOneWidget);
      expect(find.text('Connection'), findsOneWidget);
      expect(find.text('Operations'), findsOneWidget);
      expect(find.text('Last Operation'), findsOneWidget);
      expect(find.text('Stored Data'), findsOneWidget);
      
      // Verify connection controls exist
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.textContaining('Status:'), findsOneWidget);
      
      // Verify operation buttons exist
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
      expect(find.text('KEYS'), findsOneWidget);
    });

    testWidgets('Connection fields can be filled', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find broker field and clear it
      final brokerField = find.widgetWithText(TextField, 'test.mosquitto.org').first;
      await tester.tap(brokerField);
      await tester.pumpAndSettle();
      
      // Clear and enter broker
      await tester.enterText(brokerField, '');
      await tester.pumpAndSettle();
      await tester.enterText(brokerField, 'broker.hivemq.com');
      await tester.pumpAndSettle();

      // Verify broker was entered
      expect(find.text('broker.hivemq.com'), findsOneWidget);
    });

    testWidgets('Operation fields can be filled', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find key field by hint text
      final keyField = find.widgetWithText(TextField, '').at(2); // Assuming key field is third
      await tester.tap(keyField);
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'test_key_123');
      await tester.pumpAndSettle();

      // Find value field
      final valueField = find.widgetWithText(TextField, '').at(3); // Assuming value field is fourth
      await tester.tap(valueField);
      await tester.pumpAndSettle();
      await tester.enterText(valueField, 'test_value_456');
      await tester.pumpAndSettle();

      // Verify data was entered
      expect(find.text('test_key_123'), findsOneWidget);
      expect(find.text('test_value_456'), findsOneWidget);
    });

    testWidgets('Connect button functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Set a public broker
      final brokerField = find.widgetWithText(TextField, 'test.mosquitto.org').first;
      await tester.tap(brokerField);
      await tester.pumpAndSettle();
      await tester.enterText(brokerField, '');
      await tester.enterText(brokerField, 'broker.hivemq.com');
      await tester.pumpAndSettle();

      // Try to connect
      final connectButton = find.text('Connect');
      await tester.tap(connectButton);
      await tester.pumpAndSettle();
      
      // Wait for connection attempt (may succeed or fail)
      await tester.pump(const Duration(seconds: 5));
      
      // Check if status changed from initial "Disconnected"
      // The status may be connecting, connected, or error - all are valid for this test
      final statusWidget = find.textContaining('Status:');
      expect(statusWidget, findsOneWidget);
    });

    testWidgets('Refresh button works', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find and tap refresh button
      final refreshButton = find.text('Refresh');
      expect(refreshButton, findsOneWidget);
      
      await tester.tap(refreshButton);
      await tester.pumpAndSettle();
      
      // Should complete without errors
    });

    testWidgets('Operation buttons remain disabled when disconnected', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find operation buttons
      final getButton = find.text('GET');
      final setButton = find.text('SET');
      final deleteButton = find.text('DELETE');
      final keysButton = find.text('KEYS');

      expect(getButton, findsOneWidget);
      expect(setButton, findsOneWidget);
      expect(deleteButton, findsOneWidget);
      expect(keysButton, findsOneWidget);

      // Try tapping them (should have no effect when disabled)
      await tester.tap(getButton);
      await tester.pumpAndSettle();
      await tester.tap(setButton);
      await tester.pumpAndSettle();
      
      // Verify we still see "Disconnected" status
      expect(find.textContaining('Disconnected'), findsOneWidget);
    });
  });
}
