// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.


import 'package:flutter_test/flutter_test.dart';

import 'package:mocktail/mocktail.dart';
import 'package:vechicle_tracker/data/database_service.dart';
import 'package:vechicle_tracker/main.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  testWidgets('App boots up to Fleet Console', (WidgetTester tester) async {
    final mockDbService = MockDatabaseService();
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(dbService: mockDbService));

    // Verify that the AppBar title 'Fleet Console' is present
    expect(find.text('Fleet Console'), findsOneWidget);
  });
}
