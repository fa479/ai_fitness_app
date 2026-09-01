import 'package:flutter_test/flutter_test.dart';
import 'package:ai_fitness_app/main.dart';

void main() {
  testWidgets('AI Fitness app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AIFitnessApp());

    expect(find.text('AI Fitness'), findsOneWidget);
    expect(find.text('Welcome Back 👋'), findsOneWidget);
  });
}