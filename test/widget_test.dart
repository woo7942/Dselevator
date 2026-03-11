import 'package:flutter_test/flutter_test.dart';
import 'package:elevator_manager/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ElevatorManagerApp());
    expect(find.byType(ElevatorManagerApp), findsOneWidget);
  });
}
